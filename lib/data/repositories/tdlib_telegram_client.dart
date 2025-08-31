import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/entities/chat.dart';
import '../../utils/tdlib_bindings.dart';
import '../../core/logging/specialized_loggers.dart';
import '../../core/logging/logging_config.dart';

class TdlibTelegramClient implements TelegramClientRepository {
  static const int apiId = 94575;
  static const String apiHash = 'a3406de8d171bb422bb6ddf3bbd800e2';

  late TdJsonClient _client;
  late StreamController<Map<String, dynamic>> _updateController;
  late StreamController<AuthenticationState> _authController;
  final TdlibLogger _logger = TdlibLogger.instance;

  @override
  Stream<Map<String, dynamic>> get updates => _updateController.stream;

  @override
  Stream<AuthenticationState> get authUpdates => _authController.stream;

  AuthenticationState _currentAuthState =
      const AuthenticationState(state: AuthorizationState.unknown);
  UserSession? _currentUser;
  final Map<int, Chat> _chats = <int, Chat>{};
  final Map<int, List<Message>> _messages = <int, List<Message>>{};

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

    // Set TDLib log verbosity level before any other operations
    _setTdLibLogVerbosity();

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
            _logger.logError('Error parsing TDLib update', error: e);
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
    _logger.logUpdate(update);
    _updateController.add(update);

    final type = update['@type'] as String;

    if (type == 'updateAuthorizationState') {
      final authState =
          AuthenticationState.fromJson(update['authorization_state']);
      _logger.logAuthState(authState.state.toString());
      _currentAuthState = authState;
      _authController.add(authState);

      _handleAuthorizationState(authState);
    } else if (type == 'updateUser' && update['user']?['is_self'] == true) {
      _currentUser = UserSession.fromJson(update['user']);
    } else if (type == 'updateNewChat') {
      _handleNewChatUpdate(update);
    } else if (type == 'updateChatLastMessage') {
      _handleChatLastMessageUpdate(update);
    } else if (type == 'updateNewMessage') {
      _handleMessageUpdate(update);
    } else if (type == 'message') {
      // Handle single message response (from getChatHistory)
      _handleMessageUpdate(update);
    } else if (type == 'messages') {
      // Handle batch messages response from getChatHistory
      _handleMessagesResponse(update);
    }
  }

  void _handleNewChatUpdate(Map<String, dynamic> update) {
    try {
      final chatData = update['chat'] as Map<String, dynamic>?;
      if (chatData != null) {
        final chat = Chat.fromJson(chatData);
        _chats[chat.id] = chat;
        _logger.logRequest({
          '@type': 'chat_added_to_cache',
          'chat_id': chat.id,
          'chat_title': chat.title,
          'total_chats': _chats.length,
        });
      }
    } catch (e) {
      _logger.logError('Error processing updateNewChat', error: e);
    }
  }

  void _handleChatLastMessageUpdate(Map<String, dynamic> update) {
    try {
      final chatId = update['chat_id'] as int?;
      final lastMessageData = update['last_message'] as Map<String, dynamic>?;

      if (chatId != null &&
          lastMessageData != null &&
          _chats.containsKey(chatId)) {
        final message = Message.fromJson(lastMessageData);
        final existingChat = _chats[chatId]!;
        final updatedChat = existingChat.copyWith(
          lastMessage: message,
          lastActivity: message.date,
        );
        _chats[chatId] = updatedChat;
      }
    } catch (e) {
      _logger.logError('Error processing updateChatLastMessage', error: e);
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
    final homeDir = Platform.environment['HOME'] ?? '';
    final dbPath =
        path.join(homeDir, '.local', 'share', 'telegram_flutter_client');
    return dbPath;
  }

  Future<Map<String, dynamic>?> _sendRequest(
      Map<String, dynamic> request) async {
    _logger.logRequest(request);
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
  Future<List<Chat>> loadChats(
      {int limit = 20, int offsetOrder = 0, int offsetChatId = 0}) async {
    // Send the getChats request to trigger TDLib to send updateNewChat events
    await _sendRequest({
      '@type': 'getChats',
      'chat_list': {'@type': 'chatListMain'},
      'limit': limit,
    });

    // Wait a moment for updates to arrive
    await Future.delayed(const Duration(milliseconds: 500));

    // Return currently cached chats
    final chatList = _chats.values.toList();
    chatList.sort((a, b) {
      final aTime = a.lastActivity ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.lastActivity ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime); // Most recent first
    });

    _logger.logRequest({
      '@type': 'chats_returned_from_cache',
      'count': chatList.length,
    });

    return chatList;
  }

  @override
  Future<Chat?> getChat(int chatId) async {
    // First try to return from cache
    if (_chats.containsKey(chatId)) {
      return _chats[chatId];
    }

    // If not in cache, request it from TDLib
    await _sendRequest({
      '@type': 'getChat',
      'chat_id': chatId,
    });

    // Wait a moment for the update to arrive
    await Future.delayed(const Duration(milliseconds: 200));

    // Return from cache if it's now available
    return _chats[chatId];
  }

  /// Sets TDLib's native C++ logging verbosity level
  /// This must be called before any other TDLib operations
  void _setTdLibLogVerbosity() {
    try {
      final logLevel = LoggingConfig.tdlibLogLevel;
      final request = jsonEncode({
        '@type': 'setLogVerbosityLevel',
        'new_verbosity_level': logLevel.level,
      });

      // Use synchronous execute method for immediate effect
      _client.execute(request);

      _logger.logConnectionState(
          'Log verbosity set to level ${logLevel.level} (${logLevel.description})');
    } catch (e) {
      _logger.logError(
        'Failed to set TDLib log verbosity',
        error: e,
      );
    }
  }

  @override
  Future<List<Message>> loadMessages(int chatId, {int limit = 50, int fromMessageId = 0}) async {
    try {
      // First check if we have cached messages for initial load
      if (_messages.containsKey(chatId) && fromMessageId == 0) {
        final cachedMessages = _messages[chatId]!;
        // If we have enough messages cached, return them
        if (cachedMessages.length >= 30) {
          return cachedMessages;
        }
        // Otherwise, continue to load more messages
      }

      // For initial load, try to get at least 30 messages
      final minMessages = fromMessageId == 0 ? 30 : limit;
      return await _loadMessagesRecursively(chatId, minMessages, fromMessageId);
    } catch (e) {
      _logger.logError('Failed to load messages for chat $chatId', error: e);
      return _messages[chatId] ?? [];
    }
  }

  Future<List<Message>> _loadMessagesRecursively(
    int chatId, 
    int minMessages, 
    int fromMessageId,
    {int maxAttempts = 5}
  ) async {
    int attempts = 0;
    int currentFromMessageId = fromMessageId;
    
    while (attempts < maxAttempts) {
      attempts++;
      
      _logger.logRequest({
        '@type': 'recursive_load_attempt',
        'chat_id': chatId,
        'attempt': attempts,
        'from_message_id': currentFromMessageId,
        'current_cached': _messages[chatId]?.length ?? 0,
        'target': minMessages,
      });

      // Request messages from TDLib
      await _sendRequest({
        '@type': 'getChatHistory',
        'chat_id': chatId,
        'limit': 50,
        'from_message_id': currentFromMessageId,
        'offset': 0,
        'only_local': false,
      });

      // Wait for messages to be received via updates
      await Future.delayed(const Duration(milliseconds: 800));

      final currentMessages = _messages[chatId] ?? [];
      
      // If we have enough messages or no new messages were received, stop
      if (currentMessages.length >= minMessages || currentMessages.isEmpty) {
        break;
      }
      
      // Get the oldest message ID for next request
      final oldestMessage = currentMessages.reduce((a, b) => a.date.isBefore(b.date) ? a : b);
      currentFromMessageId = oldestMessage.id;
      
      // Small delay to avoid overwhelming TDLib
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final finalMessages = _messages[chatId] ?? [];
    
    _logger.logRequest({
      '@type': 'recursive_load_completed',
      'chat_id': chatId,
      'attempts_made': attempts,
      'final_message_count': finalMessages.length,
      'target_reached': finalMessages.length >= minMessages,
    });

    return finalMessages;
  }

  @override
  Future<Message?> sendMessage(int chatId, String text) async {
    try {
      final request = {
        '@type': 'sendMessage',
        'chat_id': chatId,
        'input_message_content': {
          '@type': 'inputMessageText',
          'text': {
            '@type': 'formattedText',
            'text': text,
            'entities': <dynamic>[],
          },
        },
      };

      await _sendRequest(request);
      
      // For now, return null. The actual message will come via updateNewMessage
      return null;
    } catch (e) {
      _logger.logError('Failed to send message to chat $chatId', error: e);
      return null;
    }
  }

  @override
  Future<void> markAsRead(int chatId, int messageId) async {
    try {
      await _sendRequest({
        '@type': 'viewMessages',
        'chat_id': chatId,
        'message_ids': [messageId],
        'force_read': true,
      });
    } catch (e) {
      _logger.logError('Failed to mark message as read in chat $chatId', error: e);
    }
  }

  @override
  Future<bool> deleteMessage(int chatId, int messageId) async {
    try {
      await _sendRequest({
        '@type': 'deleteMessages',
        'chat_id': chatId,
        'message_ids': [messageId],
        'revoke': true,
      });
      
      // Remove from local cache
      if (_messages.containsKey(chatId)) {
        _messages[chatId]!.removeWhere((msg) => msg.id == messageId);
      }
      
      return true;
    } catch (e) {
      _logger.logError('Failed to delete message $messageId in chat $chatId', error: e);
      return false;
    }
  }

  @override
  Future<Message?> editMessage(int chatId, int messageId, String newText) async {
    try {
      await _sendRequest({
        '@type': 'editMessageText',
        'chat_id': chatId,
        'message_id': messageId,
        'input_message_content': {
          '@type': 'inputMessageText',
          'text': {
            '@type': 'formattedText',
            'text': newText,
            'entities': <dynamic>[],
          },
        },
      });
      
      return null; // Updated message will come via updates
    } catch (e) {
      _logger.logError('Failed to edit message $messageId in chat $chatId', error: e);
      return null;
    }
  }

  void _handleMessageUpdate(Map<String, dynamic> update) {
    try {
      final message = update['message'] as Map<String, dynamic>?;
      if (message == null) return;

      final chatId = message['chat_id'] as int?;
      if (chatId == null) return;

      final messageObj = Message.fromJson(message);

      // Add to message cache
      if (!_messages.containsKey(chatId)) {
        _messages[chatId] = <Message>[];
      }

      // Check if message already exists (to avoid duplicates)
      final existingIndex = _messages[chatId]!.indexWhere((msg) => msg.id == messageObj.id);
      if (existingIndex != -1) {
        _messages[chatId]![existingIndex] = messageObj;
      } else {
        _messages[chatId]!.insert(0, messageObj);
        // Keep only the most recent 100 messages per chat
        if (_messages[chatId]!.length > 100) {
          _messages[chatId] = _messages[chatId]!.take(100).toList();
        }
      }

      _logger.logRequest({
        '@type': 'message_added_to_cache',
        'chat_id': chatId,
        'message_id': messageObj.id,
        'total_messages': _messages[chatId]!.length,
      });
    } catch (e) {
      _logger.logError('Error handling message update', error: e);
    }
  }

  void _handleMessagesResponse(Map<String, dynamic> update) {
    try {
      final messages = update['messages'] as List?;
      if (messages == null || messages.isEmpty) return;

      _logger.logRequest({
        '@type': 'processing_messages_batch',
        'message_count': messages.length,
      });

      // Process each message in the batch
      for (final messageData in messages) {
        if (messageData is Map<String, dynamic>) {
          final chatId = messageData['chat_id'] as int?;
          if (chatId == null) continue;

          final messageObj = Message.fromJson(messageData);

          // Add to message cache
          if (!_messages.containsKey(chatId)) {
            _messages[chatId] = <Message>[];
          }

          // Check if message already exists (to avoid duplicates)
          final existingIndex = _messages[chatId]!.indexWhere((msg) => msg.id == messageObj.id);
          if (existingIndex != -1) {
            _messages[chatId]![existingIndex] = messageObj;
          } else {
            // Insert messages in chronological order (oldest first)
            _messages[chatId]!.add(messageObj);
          }
        }
      }

      // Sort messages by date for each chat
      for (final chatId in _messages.keys) {
        _messages[chatId]!.sort((a, b) => a.date.compareTo(b.date));
        // Keep only the most recent 100 messages per chat
        if (_messages[chatId]!.length > 100) {
          _messages[chatId] = _messages[chatId]!.skip(_messages[chatId]!.length - 100).toList();
        }
      }

      _logger.logRequest({
        '@type': 'messages_batch_processed',
        'total_chats_updated': _messages.length,
      });
    } catch (e) {
      _logger.logError('Error handling messages response', error: e);
    }
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
