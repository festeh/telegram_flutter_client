import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/auth_notifier.dart';
import '../state/unified_auth_state.dart';

// Single source of truth for all authentication state
final authProvider = AsyncNotifierProvider<AuthNotifier, UnifiedAuthState>(
  () => AuthNotifier(),
);

// Clean extension methods for convenient UI access
extension AuthX on WidgetRef {
  // State access
  UnifiedAuthState? get auth => watch(authProvider).valueOrNull;
  bool get isAuthLoading => watch(authProvider).isLoading;
  bool get hasAuthError => watch(authProvider).hasError;
  String? get authError => watch(authProvider).error?.toString();

  // Computed properties - these will trigger rebuilds only when specific values change
  bool get isAuthenticated => watch(authProvider
      .select((state) => state.valueOrNull?.isAuthenticated ?? false));

  bool get needsPhoneNumber => watch(authProvider
      .select((state) => state.valueOrNull?.needsPhoneNumber ?? false));

  bool get needsCode => watch(
      authProvider.select((state) => state.valueOrNull?.needsCode ?? false));

  bool get needsPassword => watch(authProvider
      .select((state) => state.valueOrNull?.needsPassword ?? false));

  bool get needsRegistration => watch(authProvider
      .select((state) => state.valueOrNull?.needsRegistration ?? false));

  bool get needsQrConfirmation => watch(authProvider
      .select((state) => state.valueOrNull?.needsQrConfirmation ?? false));

  bool get isLoading => watch(
      authProvider.select((state) => state.valueOrNull?.isLoading ?? false));

  String? get errorMessage =>
      watch(authProvider.select((state) => state.valueOrNull?.errorMessage));

  // User info access
  dynamic get currentUser =>
      watch(authProvider.select((state) => state.valueOrNull?.user));

  // Additional auth info
  dynamic get codeInfo =>
      watch(authProvider.select((state) => state.valueOrNull?.codeInfo));

  dynamic get qrCodeInfo =>
      watch(authProvider.select((state) => state.valueOrNull?.qrCodeInfo));

  // Action shortcuts - these don't trigger rebuilds
  AuthNotifier get authActions => read(authProvider.notifier);

  // Convenience action methods
  Future<void> submitPhoneNumber(String phone) =>
      authActions.submitPhoneNumber(phone);

  Future<void> submitVerificationCode(String code) =>
      authActions.submitVerificationCode(code);

  Future<void> submitPassword(String password) =>
      authActions.submitPassword(password);

  Future<void> requestQrCode() => authActions.requestQrCode();

  Future<void> resendCode() => authActions.resendCode();

  Future<void> registerUser(String firstName, String lastName) =>
      authActions.registerUser(firstName, lastName);

  Future<void> logout() => authActions.logout();

  void clearError() => authActions.clearError();
}

// Legacy provider names for backward compatibility during migration (optional)
// These can be removed once all widgets are updated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider
      .select((state) => state.valueOrNull?.isAuthenticated ?? false));
});
