import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/entities/chat.dart';
import '../../domain/events/chat_events.dart';
import '../../domain/events/message_events.dart';
import '../../utils/tdlib_bindings.dart';
import '../../core/logging/specialized_loggers.dart';
import '../../core/logging/logging_config.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/tdlib_constants.dart';

/// Event for when a file download completes
class FileDownloadComplete {
  final int fileId;
  final String path;

  FileDownloadComplete(this.fileId, this.path);
}

class TdlibTelegramClient implements TelegramClientRepository {
  static int get apiId => int.parse(dotenv.env['TELEGRAM_API_ID'] ?? '0');
  static String get apiHash => dotenv.env['TELEGRAM_API_HASH'] ?? '';

  late TdJsonClient _client;
  late StreamController<Map<String, dynamic>> _updateController;
  late StreamController<AuthenticationState> _authController;
  late StreamController<FileDownloadComplete> _fileDownloadController;
  late StreamController<ChatEvent> _chatEventController;
  late StreamController<MessageEvent> _messageEventController;
  final TdlibLogger _logger = TdlibLogger.instance;

  @override
  Stream<Map<String, dynamic>> get updates => _updateController.stream;

  @override
  Stream<AuthenticationState> get authUpdates => _authController.stream;

  @override
  Stream<ChatEvent> get chatEvents => _chatEventController.stream;

  @override
  Stream<MessageEvent> get messageEvents => _messageEventController.stream;

  AuthenticationState _currentAuthState =
      const AuthenticationState(state: AuthorizationState.unknown);
  UserSession? _currentUser;
  final Map<int, Chat> _chats = <int, Chat>{};
  final Map<int, List<Message>> _messages = <int, List<Message>>{};
  final Map<int, String> _userNames = <int, String>{};
  // Track file ID to message ID mapping for photo updates
  final Map<int, ({int chatId, int messageId})> _photoFileToMessage = {};
  // Track file ID to message ID mapping for sticker updates
  final Map<int, ({int chatId, int messageId})> _stickerFileToMessage = {};

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
    _fileDownloadController = StreamController<FileDownloadComplete>.broadcast();
    _chatEventController = StreamController<ChatEvent>.broadcast();
    _messageEventController = StreamController<MessageEvent>.broadcast();
  }

  /// Stream of file download completion events
  Stream<FileDownloadComplete> get fileDownloads => _fileDownloadController.stream;

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
    _receiveTimer = Timer.periodic(AppConfig.updatePollingInterval, (timer) {
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

    final type = update[TdlibFields.type] as String;

    if (type == TdlibUpdateTypes.authorizationState) {
      final authState =
          AuthenticationState.fromJson(update['authorization_state']);
      _logger.logAuthState(authState.state.toString());
      _currentAuthState = authState;
      _authController.add(authState);

      _handleAuthorizationState(authState);
    } else if (type == TdlibUpdateTypes.user) {
      _handleUserUpdate(update);
    } else if (type == TdlibUpdateTypes.newChat) {
      _handleNewChatUpdate(update);
    } else if (type == TdlibUpdateTypes.chatLastMessage) {
      _handleChatLastMessageUpdate(update);
    } else if (type == TdlibUpdateTypes.newMessage) {
      _handleMessageUpdate(update);
    } else if (type == TdlibUpdateTypes.message) {
      // Handle single message response (from getChatHistory)
      _handleMessageUpdate(update);
    } else if (type == TdlibUpdateTypes.messages) {
      // Handle batch messages response from getChatHistory
      _handleMessagesResponse(update);
    } else if (type == TdlibUpdateTypes.file) {
      _handleFileUpdate(update);
    } else if (type == TdlibUpdateTypes.chatTitle) {
      _handleChatTitleUpdate(update);
    } else if (type == TdlibUpdateTypes.chatPhoto) {
      _handleChatPhotoUpdate(update);
    } else if (type == TdlibUpdateTypes.chatOrder) {
      _chatEventController.add(ChatOrderChangedEvent());
    } else if (type == TdlibUpdateTypes.chatReadInbox) {
      _handleChatReadInboxUpdate(update);
    } else if (type == TdlibUpdateTypes.chatPosition) {
      _handleChatPositionUpdate(update);
    } else if (type == TdlibUpdateTypes.messageEdited) {
      _handleMessageEditedUpdate(update);
    } else if (type == TdlibUpdateTypes.deleteMessages) {
      _handleDeleteMessagesUpdate(update);
    } else if (type == TdlibUpdateTypes.messageContent) {
      _handleMessageContentUpdate(update);
    } else if (type == TdlibUpdateTypes.messageSendSucceeded) {
      _handleMessageSendSucceededUpdate(update);
    } else if (type == TdlibUpdateTypes.messageSendFailed) {
      _handleMessageSendFailedUpdate(update);
    }
  }

  /// Creates a Message from JSON, looking up the sender name from cache
  Message _createMessageFromJson(Map<String, dynamic> json) {
    // sender_id can be messageSenderUser (has user_id) or messageSenderChat (has chat_id)
    final senderIdMap = json['sender_id'] as Map<String, dynamic>?;
    int senderId = 0;
    String? senderName;

    if (senderIdMap != null) {
      final userId = senderIdMap['user_id'] as int?;
      if (userId != null) {
        senderId = userId;
        senderName = _userNames[senderId];
      } else {
        // It's a chat sender - use chat title if available
        final chatId = senderIdMap['chat_id'] as int?;
        if (chatId != null) {
          senderId = chatId;
          // Try to get chat title as sender name
          final chat = _chats[chatId];
          senderName = chat?.title;
        }
      }
    }

    return Message.fromJson(json, senderName: senderName);
  }

  void _handleUserUpdate(Map<String, dynamic> update) {
    try {
      final userData = update['user'] as Map<String, dynamic>?;
      if (userData == null) return;

      final userId = userData['id'] as int?;
      if (userId == null) return;

      // Cache user name (first_name + last_name)
      final firstName = userData['first_name'] as String? ?? '';
      final lastName = userData['last_name'] as String? ?? '';
      final fullName = lastName.isNotEmpty ? '$firstName $lastName' : firstName;
      if (fullName.isNotEmpty) {
        _userNames[userId] = fullName;
      }

      // Set current user if this is self
      if (userData[TdlibFields.isSelf] == true) {
        _currentUser = UserSession.fromJson(userData);
      }
    } catch (e) {
      _logger.logError('Error processing updateUser', error: e);
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
        // Emit typed event for presentation layer
        _chatEventController.add(ChatAddedEvent(chat));
      }
    } catch (e) {
      _logger.logError('Error processing updateNewChat', error: e);
    }
  }

  void _handleChatLastMessageUpdate(Map<String, dynamic> update) {
    try {
      final chatId = update['chat_id'] as int?;
      final lastMessageData = update['last_message'] as Map<String, dynamic>?;

      if (chatId != null && lastMessageData != null) {
        final message = _createMessageFromJson(lastMessageData);

        // Update cache if chat exists
        if (_chats.containsKey(chatId)) {
          final existingChat = _chats[chatId]!;
          final updatedChat = existingChat.copyWith(
            lastMessage: message,
            lastActivity: message.date,
          );
          _chats[chatId] = updatedChat;
        }

        // Emit typed event for presentation layer
        _chatEventController.add(
          ChatLastMessageUpdatedEvent(chatId, message, message.date),
        );
      }
    } catch (e) {
      _logger.logError('Error processing updateChatLastMessage', error: e);
    }
  }

  void _handleChatTitleUpdate(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final title = update['title'] as String?;

    if (chatId != null && title != null) {
      // Update cache if chat exists
      if (_chats.containsKey(chatId)) {
        _chats[chatId] = _chats[chatId]!.copyWith(title: title);
      }
      // Emit typed event
      _chatEventController.add(ChatTitleUpdatedEvent(chatId, title));
    }
  }

  void _handleChatPhotoUpdate(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final photo = update['photo'] as Map<String, dynamic>?;

    if (chatId != null) {
      String? photoPath;
      if (photo != null) {
        final small = photo['small'] as Map<String, dynamic>?;
        photoPath = small?['local']?['path'] as String?;
      }

      // Update cache if chat exists
      if (_chats.containsKey(chatId)) {
        _chats[chatId] = _chats[chatId]!.copyWith(photoPath: photoPath);
      }
      // Emit typed event
      _chatEventController.add(ChatPhotoUpdatedEvent(chatId, photoPath));
    }
  }

  void _handleChatReadInboxUpdate(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final unreadCount = update['unread_count'] as int?;

    if (chatId != null && unreadCount != null) {
      // Update cache if chat exists
      if (_chats.containsKey(chatId)) {
        _chats[chatId] = _chats[chatId]!.copyWith(unreadCount: unreadCount);
      }
      // Emit typed event
      _chatEventController.add(ChatUnreadCountUpdatedEvent(chatId, unreadCount));
    }
  }

  void _handleChatPositionUpdate(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final position = update['position'] as Map<String, dynamic>?;

    if (chatId == null) return;

    // Check if position is in main list
    final list = position?['list'] as Map<String, dynamic>?;
    final isInMainList = list?[TdlibFields.type] == TdlibChatListTypes.main;
    final order = position?['order'] as String?;

    // If order is "0" or position is removed, chat is not in the list
    final hasValidPosition = isInMainList && order != null && order != '0';

    // Update cache if chat exists
    if (_chats.containsKey(chatId)) {
      _chats[chatId] = _chats[chatId]!.copyWith(isInMainList: hasValidPosition);
    }
    // Emit typed event
    _chatEventController.add(ChatPositionChangedEvent(chatId, hasValidPosition));
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
      'chat_list': {TdlibFields.type: TdlibChatListTypes.main},
      'limit': limit,
    });

    // Wait a moment for updates to arrive
    await Future.delayed(AppConfig.chatLoadDelay);

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
    await Future.delayed(AppConfig.singleChatFetchDelay);

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
        if (cachedMessages.length >= AppConfig.minCachedMessages) {
          return cachedMessages;
        }
        // Otherwise, continue to load more messages
      }

      // For initial load, try to get at least minCachedMessages
      final minMessages = fromMessageId == 0 ? AppConfig.minCachedMessages : limit;
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
    {int? maxAttempts}
  ) async {
    maxAttempts ??= AppConfig.messageLoadRetries;
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
        'limit': AppConfig.messagePageSize,
        'from_message_id': currentFromMessageId,
        'offset': 0,
        'only_local': false,
      });

      // Wait for messages to be received via updates
      await Future.delayed(AppConfig.messageLoadDelay);

      final currentMessages = _messages[chatId] ?? [];
      
      // Check if we have enough messages
      if (currentMessages.length >= minMessages) {
        break;
      }
      
      // After first attempt, if no messages were received at all, stop trying
      if (attempts > 1 && currentMessages.isEmpty) {
        break;
      }
      
      // Get the oldest message ID for next request
      final oldestMessage = currentMessages.reduce((a, b) => a.date.isBefore(b.date) ? a : b);
      currentFromMessageId = oldestMessage.id;
      
      // Small delay to avoid overwhelming TDLib
      await Future.delayed(AppConfig.retryDelay);
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

  /// Adds a message to the cache for a chat.
  /// [insertAtStart] - if true, inserts at beginning (for new incoming messages)
  ///                   if false, appends at end (for batch history loading)
  void _addMessageToCache(int chatId, Message message, {bool insertAtStart = false}) {
    if (!_messages.containsKey(chatId)) {
      _messages[chatId] = <Message>[];
    }

    final existingIndex = _messages[chatId]!.indexWhere((msg) => msg.id == message.id);
    if (existingIndex != -1) {
      _messages[chatId]![existingIndex] = message;
    } else {
      if (insertAtStart) {
        _messages[chatId]!.insert(0, message);
      } else {
        _messages[chatId]!.add(message);
      }
    }

    // Track photo file ID for download completion updates
    if (message.photoFileId != null) {
      _photoFileToMessage[message.photoFileId!] = (chatId: chatId, messageId: message.id);
    }

    // Track sticker file ID for download completion updates
    if (message.stickerFileId != null) {
      _stickerFileToMessage[message.stickerFileId!] = (chatId: chatId, messageId: message.id);
    }
  }

  void _handleMessageUpdate(Map<String, dynamic> update) {
    try {
      final message = update['message'] as Map<String, dynamic>?;
      if (message == null) return;

      final chatId = message['chat_id'] as int?;
      if (chatId == null) return;

      final messageObj = _createMessageFromJson(message);
      _addMessageToCache(chatId, messageObj, insertAtStart: true);

      // Keep only the most recent messages per chat
      if (_messages[chatId]!.length > AppConfig.maxMessagesPerChat) {
        _messages[chatId] = _messages[chatId]!.take(AppConfig.maxMessagesPerChat).toList();
      }

      _logger.logRequest({
        '@type': 'message_added_to_cache',
        'chat_id': chatId,
        'message_id': messageObj.id,
        'total_messages': _messages[chatId]!.length,
      });

      // Emit typed event for presentation layer
      _messageEventController.add(MessageAddedEvent(chatId, messageObj));
    } catch (e) {
      _logger.logError('Error handling message update', error: e);
    }
  }

  void _handleMessageEditedUpdate(Map<String, dynamic> update) {
    try {
      final messageData = update['message'] as Map<String, dynamic>?;
      if (messageData == null) return;

      final message = _createMessageFromJson(messageData);
      final chatId = message.chatId;

      // Update cache
      _addMessageToCache(chatId, message, insertAtStart: false);

      // Emit typed event
      _messageEventController.add(MessageEditedEvent(chatId, message));
    } catch (e) {
      _logger.logError('Error handling message edited update', error: e);
    }
  }

  void _handleDeleteMessagesUpdate(Map<String, dynamic> update) {
    try {
      final chatId = update['chat_id'] as int?;
      final messageIds = update['message_ids'] as List?;
      final fromCache = update['from_cache'] as bool? ?? false;

      if (chatId == null || messageIds == null) return;

      // Ignore cache cleanup events - these are just TDLib unloading messages
      if (fromCache) return;

      final ids = messageIds.whereType<int>().toList();

      // Remove from cache
      if (_messages.containsKey(chatId)) {
        _messages[chatId]!.removeWhere((msg) => ids.contains(msg.id));
      }

      // Emit typed event
      _messageEventController.add(MessagesDeletedEvent(chatId, ids));
    } catch (e) {
      _logger.logError('Error handling delete messages update', error: e);
    }
  }

  void _handleMessageContentUpdate(Map<String, dynamic> update) {
    try {
      final chatId = update['chat_id'] as int?;
      final messageId = update['message_id'] as int?;
      final newContent = update['new_content'] as Map<String, dynamic>?;

      if (chatId == null || messageId == null || newContent == null) return;

      // Emit typed event
      _messageEventController.add(MessageContentChangedEvent(chatId, messageId, newContent));
    } catch (e) {
      _logger.logError('Error handling message content update', error: e);
    }
  }

  void _handleMessageSendSucceededUpdate(Map<String, dynamic> update) {
    try {
      final messageData = update['message'] as Map<String, dynamic>?;
      if (messageData == null) return;

      final message = _createMessageFromJson(messageData);
      final chatId = message.chatId;

      // Update cache
      _addMessageToCache(chatId, message, insertAtStart: false);

      // Emit typed event
      _messageEventController.add(MessageSendSucceededEvent(chatId, message));
    } catch (e) {
      _logger.logError('Error handling message send succeeded update', error: e);
    }
  }

  void _handleMessageSendFailedUpdate(Map<String, dynamic> update) {
    try {
      final error = update['error'] as Map<String, dynamic>?;
      final errorMessage = error?['message'] as String? ?? 'Unknown error';

      // Emit typed event
      _messageEventController.add(MessageSendFailedEvent(errorMessage));
    } catch (e) {
      _logger.logError('Error handling message send failed update', error: e);
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

      // Group messages by chat
      final messagesByChat = <int, List<Message>>{};

      for (final messageData in messages) {
        if (messageData is Map<String, dynamic>) {
          final chatId = messageData['chat_id'] as int?;
          if (chatId == null) continue;

          final messageObj = _createMessageFromJson(messageData);
          _addMessageToCache(chatId, messageObj, insertAtStart: false);

          messagesByChat.putIfAbsent(chatId, () => []);
          messagesByChat[chatId]!.add(messageObj);
        }
      }

      // Sort and trim messages for updated chats only
      for (final chatId in messagesByChat.keys) {
        _messages[chatId]!.sort((a, b) => a.date.compareTo(b.date));
        if (_messages[chatId]!.length > AppConfig.maxMessagesPerChat) {
          _messages[chatId] = _messages[chatId]!
              .skip(_messages[chatId]!.length - AppConfig.maxMessagesPerChat)
              .toList();
        }

        // Emit typed event for each chat
        _messageEventController.add(
          MessagesBatchReceivedEvent(chatId, messagesByChat[chatId]!),
        );
      }

      _logger.logRequest({
        '@type': 'messages_batch_processed',
        'total_chats_updated': messagesByChat.length,
      });
    } catch (e) {
      _logger.logError('Error handling messages response', error: e);
    }
  }

  void _handleFileUpdate(Map<String, dynamic> update) {
    try {
      final file = update['file'] as Map<String, dynamic>?;
      if (file == null) return;

      final fileId = file['id'] as int?;
      final local = file['local'] as Map<String, dynamic>?;
      final isComplete = local?['is_downloading_completed'] as bool? ?? false;
      final filePath = local?['path'] as String?;

      if (isComplete && fileId != null && filePath != null && filePath.isNotEmpty) {
        _logger.logRequest({
          '@type': 'file_download_completed',
          'file_id': fileId,
          'path': filePath,
        });

        // Emit event for completed download
        _fileDownloadController.add(FileDownloadComplete(fileId, filePath));

        // Update any chats that have this file ID as their photo
        _updateChatPhotoByFileId(fileId, filePath);

        // Update any messages that have this file ID as their photo
        _updateMessagePhotoByFileId(fileId, filePath);

        // Update any messages that have this file ID as their sticker
        _updateMessageStickerByFileId(fileId, filePath);
      }
    } catch (e) {
      _logger.logError('Error handling file update', error: e);
    }
  }

  void _updateChatPhotoByFileId(int fileId, String path) {
    for (final chatId in _chats.keys) {
      final chat = _chats[chatId]!;
      if (chat.photoFileId == fileId) {
        _chats[chatId] = chat.copyWith(photoPath: path);
        _logger.logRequest({
          '@type': 'chat_photo_updated',
          'chat_id': chatId,
          'file_id': fileId,
          'path': path,
        });
        // Emit typed event for presentation layer
        _chatEventController.add(ChatPhotoUpdatedEvent(chatId, path));
      }
    }
  }

  void _updateMessagePhotoByFileId(int fileId, String path) {
    final messageInfo = _photoFileToMessage[fileId];
    if (messageInfo == null) return;

    final chatId = messageInfo.chatId;
    final messageId = messageInfo.messageId;

    // Find and update the message in cache
    final messages = _messages[chatId];
    if (messages == null) return;

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final updatedMessage = messages[index].copyWith(photoPath: path);
    messages[index] = updatedMessage;

    _logger.logRequest({
      '@type': 'message_photo_updated',
      'chat_id': chatId,
      'message_id': messageId,
      'file_id': fileId,
      'path': path,
    });

    // Emit typed event for presentation layer
    _messageEventController.add(MessagePhotoUpdatedEvent(chatId, messageId, path));

    // Clean up tracking
    _photoFileToMessage.remove(fileId);
  }

  void _updateMessageStickerByFileId(int fileId, String path) {
    final messageInfo = _stickerFileToMessage[fileId];
    if (messageInfo == null) return;

    final chatId = messageInfo.chatId;
    final messageId = messageInfo.messageId;

    // Find and update the message in cache
    final messages = _messages[chatId];
    if (messages == null) return;

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final updatedMessage = messages[index].copyWith(stickerPath: path);
    messages[index] = updatedMessage;

    _logger.logRequest({
      '@type': 'message_sticker_updated',
      'chat_id': chatId,
      'message_id': messageId,
      'file_id': fileId,
      'path': path,
    });

    // Emit typed event for presentation layer
    _messageEventController.add(MessageStickerUpdatedEvent(chatId, messageId, path));

    // Clean up tracking
    _stickerFileToMessage.remove(fileId);
  }

  @override
  Future<void> downloadFile(int fileId) async {
    await _sendRequest({
      '@type': 'downloadFile',
      'file_id': fileId,
      'priority': 1,
      'synchronous': false,
    });
  }

  @override
  void dispose() {
    _receiveTimer?.cancel();
    _updateController.close();
    _authController.close();
    _fileDownloadController.close();
    _chatEventController.close();
    _messageEventController.close();
    if (_isStarted) {
      _client.destroy();
    }
  }
}
