import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_session.dart';

class UnifiedAuthState {
  final AuthorizationState status;
  final UserSession? user;
  final CodeInfo? codeInfo;
  final QrCodeInfo? qrCodeInfo;
  final String? errorMessage;
  final bool isLoading;
  final bool isInitialized;

  const UnifiedAuthState({
    required this.status,
    this.user,
    this.codeInfo,
    this.qrCodeInfo,
    this.errorMessage,
    required this.isLoading,
    required this.isInitialized,
  });

  // Factory constructors for common states
  factory UnifiedAuthState.initial() => const UnifiedAuthState(
        status: AuthorizationState.unknown,
        isLoading: true,
        isInitialized: false,
      );

  factory UnifiedAuthState.error(String message) => UnifiedAuthState(
        status: AuthorizationState.unknown,
        errorMessage: message,
        isLoading: false,
        isInitialized: false,
      );

  // Computed properties
  bool get isAuthenticated => status == AuthorizationState.ready;
  bool get needsPhoneNumber => status == AuthorizationState.waitPhoneNumber;
  bool get needsCode => status == AuthorizationState.waitCode;
  bool get needsPassword => status == AuthorizationState.waitPassword;
  bool get needsRegistration => status == AuthorizationState.waitRegistration;
  bool get needsQrConfirmation =>
      status == AuthorizationState.waitOtherDeviceConfirmation;
  bool get isLoggingOut => status == AuthorizationState.loggingOut;
  bool get isClosed => status == AuthorizationState.closed;

  // Copy with method for immutable updates
  UnifiedAuthState copyWith({
    AuthorizationState? status,
    UserSession? user,
    CodeInfo? codeInfo,
    QrCodeInfo? qrCodeInfo,
    String? errorMessage,
    bool? isLoading,
    bool? isInitialized,
  }) {
    return UnifiedAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      codeInfo: codeInfo ?? this.codeInfo,
      qrCodeInfo: qrCodeInfo ?? this.qrCodeInfo,
      errorMessage: errorMessage ?? this.errorMessage,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }

  // Convenience method to clear error
  UnifiedAuthState clearError() {
    return copyWith(errorMessage: null);
  }

  // Convenience method to set loading
  UnifiedAuthState setLoading(bool loading) {
    return copyWith(isLoading: loading);
  }

  @override
  String toString() {
    return 'UnifiedAuthState('
        'status: $status, '
        'isAuthenticated: $isAuthenticated, '
        'isLoading: $isLoading, '
        'isInitialized: $isInitialized, '
        'errorMessage: $errorMessage'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UnifiedAuthState &&
        other.status == status &&
        other.user == user &&
        other.codeInfo == codeInfo &&
        other.qrCodeInfo == qrCodeInfo &&
        other.errorMessage == errorMessage &&
        other.isLoading == isLoading &&
        other.isInitialized == isInitialized;
  }

  @override
  int get hashCode {
    return status.hashCode ^
        user.hashCode ^
        codeInfo.hashCode ^
        qrCodeInfo.hashCode ^
        errorMessage.hashCode ^
        isLoading.hashCode ^
        isInitialized.hashCode;
  }
}
