import 'dart:async';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_session.dart';
import '../../utils/tdlib_bindings.dart';

class TdlibTelegramClient implements TelegramClientRepository {
  static const int apiId = 94575;
  static const String apiHash = 'a3406de8d171bb422bb6ddf3bbd800e2';

  late TdJsonClient _client;
  late StreamController<Map<String, dynamic>> _updateController;
  late StreamController<AuthenticationState> _authController;

  @override
  Stream<Map<String, dynamic>> get updates => _updateController.stream;

  @override
  Stream<AuthenticationState> get authUpdates => _authController.stream;

  AuthenticationState _currentAuthState =
      const AuthenticationState(state: AuthorizationState.unknown);
  UserSession? _currentUser;

  @override
  AuthenticationState get currentAuthState => _currentAuthState;

  @override
  UserSession? get currentUser => _currentUser;

  bool _isStarted = false;
  Timer? _receiveTimer;
  final List<Map<String, dynamic>> _pendingUpdates = [];

  TdlibTelegramClient() {
    _updateController = StreamController<Map<String, dynamic>>.broadcast();
    _authController = StreamController<AuthenticationState>.broadcast();
  }

  @override
  Future<void> start() async {
    if (_isStarted) return;

    _client = TdJsonClient();
    _isStarted = true;

    _startReceiving();

    final dbPath = await _getDatabasePath();

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
    _receiveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      bool hasUpdates = false;
      while (true) {
        final response = _client.receive(0.0);
        if (response != null) {
          try {
            final update = jsonDecode(response) as Map<String, dynamic>;
            _pendingUpdates.add(update);
            hasUpdates = true;
          } catch (e) {
            print('Error parsing update: $e');
          }
        } else {
          break;
        }
      }

      if (hasUpdates) {
        _processBatchedUpdates();
      }
    });
  }

  void _processBatchedUpdates() {
    final updates = List<Map<String, dynamic>>.from(_pendingUpdates);
    _pendingUpdates.clear();

    final authUpdates = updates
        .where((update) => update['@type'] == 'updateAuthorizationState')
        .toList();
    final otherUpdates = updates
        .where((update) => update['@type'] != 'updateAuthorizationState')
        .toList();

    for (final update in authUpdates) {
      _handleUpdate(update);
    }

    for (final update in otherUpdates) {
      _handleUpdate(update);
    }
  }

  void _handleUpdate(Map<String, dynamic> update) {
    _updateController.add(update);

    final type = update['@type'] as String;

    if (type == 'updateAuthorizationState') {
      final authState =
          AuthenticationState.fromJson(update['authorization_state']);
      print('TDLib auth state: ${authState.state}');
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

  Future<Map<String, dynamic>?> _sendRequest(
      Map<String, dynamic> request) async {
    final requestJson = jsonEncode(request);
    _client.send(requestJson);
    return null;
  }

  @override
  Future<void> setPhoneNumber(String phoneNumber) async {
    await _sendRequest({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': phoneNumber,
    });
  }

  @override
  Future<void> checkAuthenticationCode(String code) async {
    await _sendRequest({
      '@type': 'checkAuthenticationCode',
      'code': code,
    });
  }

  @override
  Future<void> checkAuthenticationPassword(String password) async {
    await _sendRequest({
      '@type': 'checkAuthenticationPassword',
      'password': password,
    });
  }

  @override
  Future<void> requestQrCodeAuthentication() async {
    await _sendRequest({
      '@type': 'requestQrCodeAuthentication',
      'other_user_ids': <int>[],
    });
  }

  @override
  Future<void> confirmQrCodeAuthentication(String link) async {
    await _sendRequest({
      '@type': 'confirmQrCodeAuthentication',
      'link': link,
    });
  }

  @override
  Future<void> registerUser(String firstName, String lastName) async {
    await _sendRequest({
      '@type': 'registerUser',
      'first_name': firstName,
      'last_name': lastName,
    });
  }

  @override
  Future<void> resendAuthenticationCode() async {
    await _sendRequest({
      '@type': 'resendAuthenticationCode',
    });
  }

  @override
  Future<void> logOut() async {
    await _sendRequest({
      '@type': 'logOut',
    });
  }

  @override
  void dispose() {
    _receiveTimer?.cancel();
    _updateController.close();
    _authController.close();
    if (_isStarted) {
      _client.destroy();
    }
  }
}
