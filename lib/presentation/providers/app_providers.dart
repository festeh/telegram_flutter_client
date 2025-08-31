import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/repositories/authentication_repository.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../data/repositories/tdlib_telegram_client.dart';
import '../../data/repositories/tdlib_authentication.dart';
import '../../data/repositories/shared_preferences_storage.dart';
import '../../domain/entities/auth_state.dart';

// Repository providers
final storageRepositoryProvider = Provider<StorageRepository>((ref) {
  return SharedPreferencesStorage();
});

final telegramClientRepositoryProvider =
    Provider<TelegramClientRepository>((ref) {
  return TdlibTelegramClient();
});

final authenticationRepositoryProvider =
    Provider<AuthenticationRepository>((ref) {
  return TdlibAuthentication(
    ref.watch(telegramClientRepositoryProvider),
    ref.watch(storageRepositoryProvider),
  );
});

// State providers
final authStateProvider = StreamProvider<AuthenticationState>((ref) {
  final authRepository = ref.watch(authenticationRepositoryProvider);
  return authRepository.authStateChanges;
});

// Initialization provider
final initializationProvider = FutureProvider<void>((ref) async {
  final authRepository = ref.watch(authenticationRepositoryProvider);
  await authRepository.initialize();
});

// Current auth state provider (synchronous)
final currentAuthStateProvider = Provider<AuthenticationState>((ref) {
  final authRepository = ref.watch(authenticationRepositoryProvider);
  return authRepository.authState;
});

// Authentication status helpers
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authStateAsync = ref.watch(authStateProvider);
  return authStateAsync.when(
    data: (state) => state.state == AuthorizationState.ready,
    loading: () => false,
    error: (_, __) => false,
  );
});

final isLoadingProvider = Provider<bool>((ref) {
  final authRepository = ref.watch(authenticationRepositoryProvider);
  return authRepository.isLoading;
});

final errorMessageProvider = Provider<String?>((ref) {
  final authRepository = ref.watch(authenticationRepositoryProvider);
  return authRepository.errorMessage;
});

final codeInfoProvider = Provider<CodeInfo?>((ref) {
  final authRepository = ref.watch(authenticationRepositoryProvider);
  return authRepository.codeInfo;
});

final qrCodeInfoProvider = Provider<QrCodeInfo?>((ref) {
  final authRepository = ref.watch(authenticationRepositoryProvider);
  return authRepository.qrCodeInfo;
});

final currentUserProvider = Provider((ref) {
  final authRepository = ref.watch(authenticationRepositoryProvider);
  return authRepository.currentUser;
});
