import 'dart:async';
import 'dart:convert';
import '../../domain/repositories/authentication_repository.dart';
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/repositories/storage_repository.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_session.dart';
import '../../core/logging/specialized_loggers.dart';

class TdlibAuthentication implements AuthenticationRepository {
  final TelegramClientRepository _client;
  final StorageRepository _storage;
  late StreamSubscription _authSubscription;
  late StreamSubscription _updateSubscription;
  final AuthLogger _logger = AuthLogger.instance;

  AuthenticationState _authState =
      const AuthenticationState(state: AuthorizationState.unknown);
  UserSession? _currentUser;
  CodeInfo? _codeInfo;
  QrCodeInfo? _qrCodeInfo;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isInitialized = false;

  final StreamController<AuthenticationState> _authStateController =
      StreamController<AuthenticationState>.broadcast();

  TdlibAuthentication(this._client, this._storage) {
    _authSubscription = _client.authUpdates.listen(_onAuthUpdate);
    _updateSubscription = _client.updates.listen(_onUpdate);
  }

  @override
  AuthenticationState get authState => _authState;

  @override
  bool get isInitialized => _isInitialized;

  @override
  UserSession? get currentUser => _currentUser;

  @override
  CodeInfo? get codeInfo => _codeInfo;

  @override
  QrCodeInfo? get qrCodeInfo => _qrCodeInfo;

  @override
  String? get errorMessage => _errorMessage;

  @override
  bool get isLoading => _isLoading;

  @override
  bool get isAuthenticated => _authState.state == AuthorizationState.ready;

  @override
  bool get needsPhoneNumber =>
      _authState.state == AuthorizationState.waitPhoneNumber;

  @override
  bool get needsCode => _authState.state == AuthorizationState.waitCode;

  @override
  bool get needsPassword => _authState.state == AuthorizationState.waitPassword;

  @override
  bool get needsRegistration =>
      _authState.state == AuthorizationState.waitRegistration;

  @override
  bool get needsQrConfirmation =>
      _authState.state == AuthorizationState.waitOtherDeviceConfirmation;

  @override
  Stream<AuthenticationState> get authStateChanges =>
      _authStateController.stream;

  void _onAuthUpdate(AuthenticationState state) {
    _logger.logAuthStart(state.state.toString());
    _authState = state;
    _errorMessage = null;
    _isLoading = false;

    if (state.state != AuthorizationState.waitCode) {
      _codeInfo = null;
    }
    if (state.state != AuthorizationState.waitOtherDeviceConfirmation) {
      _qrCodeInfo = null;
    }

    _authStateController.add(_authState);
  }

  void _onUpdate(Map<String, dynamic> update) {
    final type = update['@type'] as String;

    switch (type) {
      case 'updateAuthorizationState':
        final authStateData =
            update['authorization_state'] as Map<String, dynamic>;
        final authStateType = authStateData['@type'] as String;

        if (authStateType == 'authorizationStateWaitCode') {
          _codeInfo = CodeInfo.fromJson(authStateData);
          _authStateController.add(_authState);
        } else if (authStateType ==
            'authorizationStateWaitOtherDeviceConfirmation') {
          _qrCodeInfo = QrCodeInfo.fromJson(authStateData);
          _authStateController.add(_authState);
        }
        break;

      case 'updateUser':
        if (update['user']?['is_self'] == true) {
          _currentUser = UserSession.fromJson(update['user']);
          _saveUserSession();
          _logger.logAuthSuccess(_currentUser?.userId.toString() ?? 'unknown');
          _authStateController.add(_authState);
        }
        break;

      case 'error':
        _errorMessage = update['message'] ?? 'Unknown error occurred';
        _isLoading = false;
        _authStateController.add(_authState);
        break;
    }
  }

  @override
  Future<void> initialize() async {
    try {
      await _loadUserSession();
      await _client.start();
      _isInitialized = true;
      _authStateController.add(_authState);
    } catch (e) {
      _logger.logError('Authentication initialization failed', error: e);
      _isInitialized = true;
      _authStateController.add(_authState);
      rethrow;
    }
  }

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _errorMessage = 'Phone number is required';
      _authStateController.add(_authState);
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _authStateController.add(_authState);

    try {
      _logger.logPhoneNumberSubmission();
      await _client.setPhoneNumber(phoneNumber);
    } catch (e) {
      _logger.logAuthFailure('Phone number submission failed', error: e);
      _errorMessage = 'Failed to send phone number: $e';
      _isLoading = false;
      _authStateController.add(_authState);
    }
  }

  @override
  Future<void> submitVerificationCode(String code) async {
    if (code.isEmpty) {
      _errorMessage = 'Verification code is required';
      _authStateController.add(_authState);
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _authStateController.add(_authState);

    try {
      _logger.logCodeSubmission();
      await _client.checkAuthenticationCode(code);
    } catch (e) {
      _logger.logAuthFailure('Code verification failed', error: e);
      _errorMessage = 'Invalid verification code: $e';
      _isLoading = false;
      _authStateController.add(_authState);
    }
  }

  @override
  Future<void> submitPassword(String password) async {
    if (password.isEmpty) {
      _errorMessage = 'Password is required';
      _authStateController.add(_authState);
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _authStateController.add(_authState);

    try {
      _logger.logPasswordSubmission();
      await _client.checkAuthenticationPassword(password);
    } catch (e) {
      _logger.logAuthFailure('Password authentication failed', error: e);
      _errorMessage = 'Invalid password: $e';
      _isLoading = false;
      _authStateController.add(_authState);
    }
  }

  @override
  Future<void> requestQrCode() async {
    _isLoading = true;
    _errorMessage = null;
    _authStateController.add(_authState);

    try {
      _logger.logQrCodeRequest();
      await _client.requestQrCodeAuthentication();
    } catch (e) {
      _logger.logAuthFailure('QR code request failed', error: e);
      _errorMessage = 'Failed to request QR code: $e';
      _isLoading = false;
      _authStateController.add(_authState);
    }
  }

  @override
  Future<void> resendCode() async {
    _isLoading = true;
    _errorMessage = null;
    _authStateController.add(_authState);

    try {
      await _client.resendAuthenticationCode();
    } catch (e) {
      _errorMessage = 'Failed to resend code: $e';
      _isLoading = false;
      _authStateController.add(_authState);
    }
  }

  @override
  Future<void> registerUser(String firstName, String lastName) async {
    if (firstName.isEmpty) {
      _errorMessage = 'First name is required';
      _authStateController.add(_authState);
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _authStateController.add(_authState);

    try {
      await _client.registerUser(firstName, lastName);
    } catch (e) {
      _errorMessage = 'Failed to register: $e';
      _isLoading = false;
      _authStateController.add(_authState);
    }
  }

  @override
  Future<void> logOut() async {
    _isLoading = true;
    _authStateController.add(_authState);

    try {
      _logger.logLogout(_currentUser?.userId.toString());
      await _client.logOut();
      await _clearUserSession();
    } catch (e) {
      _logger.logAuthFailure('Logout failed', error: e);
      _errorMessage = 'Failed to log out: $e';
      _isLoading = false;
      _authStateController.add(_authState);
    }
  }

  @override
  void clearError() {
    _errorMessage = null;
    _authStateController.add(_authState);
  }

  Future<void> _saveUserSession() async {
    if (_currentUser == null) return;

    try {
      await _storage.setString(
          'user_session', jsonEncode(_currentUser!.toJson()));
    } catch (e) {
      _logger.logError('Failed to save user session', error: e);
    }
  }

  Future<void> _loadUserSession() async {
    try {
      final sessionData = await _storage.getString('user_session');
      if (sessionData != null) {
        _logger.logSessionLoad();
      }
    } catch (e) {
      _logger.logError('Failed to load user session', error: e);
    }
  }

  Future<void> _clearUserSession() async {
    try {
      await _storage.remove('user_session');
      _currentUser = null;
    } catch (e) {
      _logger.logError('Failed to clear user session', error: e);
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _updateSubscription.cancel();
    _authStateController.close();
    _client.dispose();
  }
}
