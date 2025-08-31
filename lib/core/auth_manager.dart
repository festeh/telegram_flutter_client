import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tdlib_client.dart';
import '../models/auth_state.dart';
import '../models/user_session.dart';

class AuthManager extends ChangeNotifier {
  final TelegramClient _client;
  late StreamSubscription _authSubscription;
  late StreamSubscription _updateSubscription;
  
  AuthenticationState _authState = const AuthenticationState(state: AuthorizationState.unknown);
  UserSession? _currentUser;
  CodeInfo? _codeInfo;
  QrCodeInfo? _qrCodeInfo;
  String? _errorMessage;
  bool _isLoading = false;
  bool _isInitialized = false;
  
  AuthenticationState get authState => _authState;
  bool get isInitialized => _isInitialized;
  UserSession? get currentUser => _currentUser;
  CodeInfo? get codeInfo => _codeInfo;
  QrCodeInfo? get qrCodeInfo => _qrCodeInfo;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  
  bool get isAuthenticated => _authState.state == AuthorizationState.ready;
  bool get needsPhoneNumber => _authState.state == AuthorizationState.waitPhoneNumber;
  bool get needsCode => _authState.state == AuthorizationState.waitCode;
  bool get needsPassword => _authState.state == AuthorizationState.waitPassword;
  bool get needsRegistration => _authState.state == AuthorizationState.waitRegistration;
  bool get needsQrConfirmation => _authState.state == AuthorizationState.waitOtherDeviceConfirmation;
  
  AuthManager(this._client) {
    _authSubscription = _client.authUpdates.listen(_onAuthUpdate);
    _updateSubscription = _client.updates.listen(_onUpdate);
  }
  
  void _onAuthUpdate(AuthenticationState state) {
    print('Auth state changed to: ${state.state}');
    _authState = state;
    _errorMessage = null;
    _isLoading = false;
    
    // Reset specific state info when changing states
    if (state.state != AuthorizationState.waitCode) {
      _codeInfo = null;
    }
    if (state.state != AuthorizationState.waitOtherDeviceConfirmation) {
      _qrCodeInfo = null;
    }
    
    notifyListeners();
  }
  
  void _onUpdate(Map<String, dynamic> update) {
    final type = update['@type'] as String;
    
    switch (type) {
      case 'updateAuthorizationState':
        final authStateData = update['authorization_state'] as Map<String, dynamic>;
        final authStateType = authStateData['@type'] as String;
        
        if (authStateType == 'authorizationStateWaitCode') {
          _codeInfo = CodeInfo.fromJson(authStateData);
          notifyListeners();
        } else if (authStateType == 'authorizationStateWaitOtherDeviceConfirmation') {
          _qrCodeInfo = QrCodeInfo.fromJson(authStateData);
          notifyListeners();
        }
        break;
        
      case 'updateUser':
        if (update['user']?['is_self'] == true) {
          _currentUser = UserSession.fromJson(update['user']);
          _saveUserSession();
          print('User session updated: ${_currentUser?.displayName}');
          notifyListeners();
        }
        break;
        
      case 'error':
        _errorMessage = update['message'] ?? 'Unknown error occurred';
        _isLoading = false;
        notifyListeners();
        break;
    }
  }
  
  Future<void> initialize() async {
    try {
      // Step 1: Load cached user session (fast)
      await _loadUserSession();
      
      // Step 2: Start TDLib client (slower but essential)
      await _client.start();
      
      // Step 3: Mark as initialized
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      print('Initialization failed: $e');
      _isInitialized = true; // Allow app to continue even if init fails
      notifyListeners();
      rethrow;
    }
  }
  
  Future<void> submitPhoneNumber(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _errorMessage = 'Phone number is required';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _client.setPhoneNumber(phoneNumber);
    } catch (e) {
      _errorMessage = 'Failed to send phone number: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> submitVerificationCode(String code) async {
    if (code.isEmpty) {
      _errorMessage = 'Verification code is required';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _client.checkAuthenticationCode(code);
    } catch (e) {
      _errorMessage = 'Invalid verification code: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> submitPassword(String password) async {
    if (password.isEmpty) {
      _errorMessage = 'Password is required';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _client.checkAuthenticationPassword(password);
    } catch (e) {
      _errorMessage = 'Invalid password: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> requestQrCode() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _client.requestQrCodeAuthentication();
    } catch (e) {
      _errorMessage = 'Failed to request QR code: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> resendCode() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _client.resendAuthenticationCode();
    } catch (e) {
      _errorMessage = 'Failed to resend code: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> registerUser(String firstName, String lastName) async {
    if (firstName.isEmpty) {
      _errorMessage = 'First name is required';
      notifyListeners();
      return;
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      await _client.registerUser(firstName, lastName);
    } catch (e) {
      _errorMessage = 'Failed to register: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  Future<void> logOut() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _client.logOut();
      await _clearUserSession();
    } catch (e) {
      _errorMessage = 'Failed to log out: $e';
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
  
  Future<void> _saveUserSession() async {
    if (_currentUser == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_session', _currentUser!.toJson().toString());
    } catch (e) {
      print('Failed to save user session: $e');
    }
  }
  
  Future<void> _loadUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sessionData = prefs.getString('user_session');
      if (sessionData != null) {
        // Note: In a real implementation, you'd parse this properly
        // For now, we'll let TDLib handle session restoration
        print('Found cached user session');
      }
      // This completes quickly regardless, allowing UI to show sooner
    } catch (e) {
      print('Failed to load user session: $e');
      // Don't rethrow - this shouldn't block initialization
    }
  }
  
  Future<void> _clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_session');
      _currentUser = null;
    } catch (e) {
      print('Failed to clear user session: $e');
    }
  }
  
  @override
  void dispose() {
    _authSubscription.cancel();
    _updateSubscription.cancel();
    _client.dispose();
    super.dispose();
  }
}