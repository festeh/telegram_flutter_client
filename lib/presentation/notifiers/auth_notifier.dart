import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/authentication_repository.dart';
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../data/repositories/tdlib_authentication.dart';
import '../../data/repositories/shared_preferences_storage.dart';
import '../../domain/entities/auth_state.dart';
import '../state/unified_auth_state.dart';
import '../providers/telegram_client_provider.dart';

class AuthNotifier extends AsyncNotifier<UnifiedAuthState> {
  TelegramClientRepository get _client => ref.read(telegramClientProvider);
  StorageRepository? _storage;
  AuthenticationRepository? _authRepository;
  StreamSubscription<AuthenticationState>? _authSubscription;

  @override
  Future<UnifiedAuthState> build() async {
    // Initialize dependencies - use shared client from provider
    _storage ??= SharedPreferencesStorage();
    _authRepository ??= TdlibAuthentication(_client, _storage!);

    // Initialize the repository
    await _authRepository!.initialize();

    // Set up state listening
    _listenToAuthChanges();

    // Return initial state
    return _getCurrentUnifiedState();
  }

  void _listenToAuthChanges() {
    _authSubscription?.cancel();
    _authSubscription = _authRepository!.authStateChanges.listen(
      (authState) {
        // Update state when repository state changes
        state = AsyncData(_getCurrentUnifiedState());
      },
      onError: (error) {
        state = AsyncError(error, StackTrace.current);
      },
    );
  }

  UnifiedAuthState _getCurrentUnifiedState() {
    final repo = _authRepository;
    if (repo == null) return UnifiedAuthState.initial();
    return UnifiedAuthState(
      status: repo.authState.state,
      user: repo.currentUser,
      codeInfo: repo.codeInfo,
      qrCodeInfo: repo.qrCodeInfo,
      errorMessage: repo.errorMessage,
      isLoading: repo.isLoading,
      isInitialized: repo.isInitialized,
    );
  }

  // Authentication Actions

  Future<void> submitPhoneNumber(String phoneNumber) =>
      _executeAuthAction(() => _authRepository!.submitPhoneNumber(phoneNumber));

  Future<void> submitVerificationCode(String code) =>
      _executeAuthAction(() => _authRepository!.submitVerificationCode(code));

  Future<void> submitPassword(String password) =>
      _executeAuthAction(() => _authRepository!.submitPassword(password));

  Future<void> requestQrCode() =>
      _executeAuthAction(() => _authRepository!.requestQrCode());

  Future<void> confirmQrCode(String link) =>
      _executeAuthAction(() => _authRepository!.confirmQrCode(link));

  Future<void> resendCode() =>
      _executeAuthAction(() => _authRepository!.resendCode());

  Future<void> registerUser(String firstName, String lastName) =>
      _executeAuthAction(
        () => _authRepository!.registerUser(firstName, lastName),
      );

  Future<void> logout() => _executeAuthAction(() => _authRepository!.logOut());

  /// Executes an auth action with standardized loading/error handling.
  Future<void> _executeAuthAction(Future<void> Function() action) async {
    try {
      _setLoading(true);
      clearError();
      await action();
    } catch (error) {
      _setError(error.toString());
    } finally {
      _setLoading(false);
    }
  }

  // State Management Helpers

  void clearError() {
    _authRepository?.clearError();
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.clearError());
    }
  }

  void _setLoading(bool isLoading) {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.setLoading(isLoading));
    }
  }

  void _setError(String errorMessage) {
    final currentState = state.value ?? UnifiedAuthState.initial();
    state = AsyncData(
      currentState.copyWith(errorMessage: errorMessage, isLoading: false),
    );
  }

  // Cleanup - called when provider is disposed
  void dispose() {
    _authSubscription?.cancel();
    _authRepository?.dispose();
  }
}
