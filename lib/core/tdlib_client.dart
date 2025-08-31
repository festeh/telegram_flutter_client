import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../utils/tdlib_bindings.dart';
import '../models/auth_state.dart';
import '../models/user_session.dart';

class TelegramClient {
  static const int apiId = 94575; // Default test API ID
  static const String apiHash = 'a3406de8d171bb422bb6ddf3bbd800e2'; // Default test API hash
  
  late TdJsonClient _client;
  late StreamController<Map<String, dynamic>> _updateController;
  late StreamController<AuthenticationState> _authController;
  
  Stream<Map<String, dynamic>> get updates => _updateController.stream;
  Stream<AuthenticationState> get authUpdates => _authController.stream;
  
  AuthenticationState _currentAuthState = const AuthenticationState(state: AuthorizationState.unknown);
  UserSession? _currentUser;
  
  AuthenticationState get currentAuthState => _currentAuthState;
  UserSession? get currentUser => _currentUser;
  
  bool _isStarted = false;
  Timer? _receiveTimer;
  
  TelegramClient() {
    _updateController = StreamController<Map<String, dynamic>>.broadcast();
    _authController = StreamController<AuthenticationState>.broadcast();
  }
  
  Future<void> start() async {
    if (_isStarted) return;
    
    _client = TdJsonClient();
    _isStarted = true;
    
    _startReceiving();
    
    final dbPath = await _getDatabasePath();
    
    // Send tdlibParameters
    await _sendRequest({
      '@type': 'setTdlibParameters',
      'database_directory': dbPath,
      'files_directory': path.join(dbPath, 'files'),
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': false,
      'api_id': apiId,
      'api_hash': apiHash,
      'system_language_code': 'en',
      'device_model': 'Desktop',
      'application_version': '1.0.0',
      'enable_storage_optimizer': true,
    });
  }
  
  void _startReceiving() {
    _receiveTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      final response = _client.receive(0.1);
      if (response != null) {
        try {
          final update = jsonDecode(response) as Map<String, dynamic>;
          _handleUpdate(update);
        } catch (e) {
          print('Error parsing update: $e');
        }
      }
    });
  }
  
  void _handleUpdate(Map<String, dynamic> update) {
    _updateController.add(update);
    
    final type = update['@type'] as String;
    
    if (type == 'updateAuthorizationState') {
      final authState = AuthenticationState.fromJson(update['authorization_state']);
      _currentAuthState = authState;
      _authController.add(authState);
      
      _handleAuthorizationState(authState);
    } else if (type == 'updateUser' && update['user']?['is_self'] == true) {
      _currentUser = UserSession.fromJson(update['user']);
    }
  }
  
  void _handleAuthorizationState(AuthenticationState state) {
    switch (state.state) {
      case AuthorizationState.waitEncryptionKey:
        _sendRequest({
          '@type': 'checkDatabaseEncryptionKey',
          'encryption_key': '',
        });
        break;
      case AuthorizationState.ready:
        _getCurrentUser();
        break;
      default:
        break;
    }
  }
  
  Future<void> _getCurrentUser() async {
    await _sendRequest({'@type': 'getMe'});
  }
  
  Future<String> _getDatabasePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dbPath = path.join(appDir.path, 'telegram_flutter_client');
    return dbPath;
  }
  
  Future<Map<String, dynamic>?> _sendRequest(Map<String, dynamic> request) async {
    final requestJson = jsonEncode(request);
    _client.send(requestJson);
    return null; // For async operations, we handle responses in updates
  }
  
  // Authentication methods
  Future<void> setPhoneNumber(String phoneNumber) async {
    await _sendRequest({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': phoneNumber,
    });
  }
  
  Future<void> checkAuthenticationCode(String code) async {
    await _sendRequest({
      '@type': 'checkAuthenticationCode',
      'code': code,
    });
  }
  
  Future<void> checkAuthenticationPassword(String password) async {
    await _sendRequest({
      '@type': 'checkAuthenticationPassword',
      'password': password,
    });
  }
  
  Future<void> requestQrCodeAuthentication() async {
    await _sendRequest({
      '@type': 'requestQrCodeAuthentication',
      'other_user_ids': <int>[],
    });
  }
  
  Future<void> confirmQrCodeAuthentication(String link) async {
    await _sendRequest({
      '@type': 'confirmQrCodeAuthentication',
      'link': link,
    });
  }
  
  Future<void> registerUser(String firstName, String lastName) async {
    await _sendRequest({
      '@type': 'registerUser',
      'first_name': firstName,
      'last_name': lastName,
    });
  }
  
  Future<void> resendAuthenticationCode() async {
    await _sendRequest({
      '@type': 'resendAuthenticationCode',
    });
  }
  
  Future<void> logOut() async {
    await _sendRequest({
      '@type': 'logOut',
    });
  }
  
  void dispose() {
    _receiveTimer?.cancel();
    _updateController.close();
    _authController.close();
    if (_isStarted) {
      _client.destroy();
    }
  }
}