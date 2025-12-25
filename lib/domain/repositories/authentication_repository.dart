import 'dart:async';
import '../entities/auth_state.dart';
import '../entities/user_session.dart';

abstract class AuthenticationRepository {
  // State getters
  AuthenticationState get authState;
  bool get isInitialized;
  UserSession? get currentUser;
  CodeInfo? get codeInfo;
  QrCodeInfo? get qrCodeInfo;
  String? get errorMessage;
  bool get isLoading;

  // Auth state helpers
  bool get isAuthenticated;
  bool get needsPhoneNumber;
  bool get needsCode;
  bool get needsPassword;
  bool get needsRegistration;
  bool get needsQrConfirmation;

  // State changes stream
  Stream<AuthenticationState> get authStateChanges;

  // Initialization
  Future<void> initialize();

  // Authentication actions
  Future<void> submitPhoneNumber(String phoneNumber);
  Future<void> submitVerificationCode(String code);
  Future<void> submitPassword(String password);
  Future<void> requestQrCode();
  Future<void> confirmQrCode(String link);
  Future<void> resendCode();
  Future<void> registerUser(String firstName, String lastName);
  Future<void> logOut();

  // Utility
  void clearError();
  void dispose();
}
