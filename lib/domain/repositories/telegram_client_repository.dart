import 'dart:async';
import '../entities/auth_state.dart';
import '../entities/user_session.dart';

abstract class TelegramClientRepository {
  Stream<Map<String, dynamic>> get updates;
  Stream<AuthenticationState> get authUpdates;

  AuthenticationState get currentAuthState;
  UserSession? get currentUser;

  Future<void> start();

  // Authentication methods
  Future<void> setPhoneNumber(String phoneNumber);
  Future<void> checkAuthenticationCode(String code);
  Future<void> checkAuthenticationPassword(String password);
  Future<void> requestQrCodeAuthentication();
  Future<void> confirmQrCodeAuthentication(String link);
  Future<void> registerUser(String firstName, String lastName);
  Future<void> resendAuthenticationCode();
  Future<void> logOut();

  void dispose();
}
