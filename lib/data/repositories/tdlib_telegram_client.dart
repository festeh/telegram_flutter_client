import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user_session.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/sticker.dart';
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

  TdJsonClient? _client;
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

  AuthenticationState _currentAuthState = const AuthenticationState(
    state: AuthorizationState.unknown,
  );
  UserSession? _currentUser;
  final Map<int, Chat> _chats = <int, Chat>{};
  final Map<int, List<Message>> _messages = <int, List<Message>>{};
  final Map<int, String> _userNames = <int, String>{};
  // Cache user online status
  final Map<int, String> _userStatuses = <int, String>{};
  // Track file ID to message ID mapping for photo updates
  final Map<int, ({int chatId, int messageId})> _photoFileToMessage = {};
  // Track file ID to message ID mapping for sticker updates
  final Map<int, ({int chatId, int messageId})> _stickerFileToMessage = {};
  // Track file ID to message ID mapping for video updates
  final Map<int, ({int chatId, int messageId})> _videoFileToMessage = {};

  // Sticker file cache: fileId -> localPath (for picker caching)
  final Map<int, String> _stickerFileCache = {};
  // Track pending downloads to avoid duplicate requests
  final Set<int> _pendingDownloads = {};

  // Custom emoji caches
  // customEmojiId -> file path (when downloaded)
  final Map<int, String> _customEmojiCache = {};
  // customEmojiId -> file ID (for download tracking)
  final Map<int, int> _customEmojiFileIds = {};
  // fileId -> customEmojiId (reverse mapping for download completion)
  final Map<int, int> _fileIdToCustomEmoji = {};
  // customEmojiId -> set of (chatId, messageId) that use this emoji
  final Map<int, Set<({int chatId, int messageId})>> _customEmojiToMessages =
      {};
  // Track pending custom emoji fetches to avoid duplicate requests
  final Set<int> _pendingCustomEmojiFetches = {};

  // Reply message cache: (chatId, messageId) -> Message
  final Map<(int, int), Message> _replyMessageCache = {};
  // Track pending reply message fetches to avoid duplicate requests
  final Set<(int, int)> _pendingReplyFetches = {};

  // Request-response correlation using TDLib's @extra field
  int _requestId = 0;
  final Map<String, Completer<Map<String, dynamic>?>> _pendingRequests = {};

  @override
  AuthenticationState get currentAuthState => _currentAuthState;

  @override
  UserSession? get currentUser => _currentUser;

  Timer? _receiveTimer;
  final List<Map<String, dynamic>> _pendingUpdates = [];

  TdlibTelegramClient() {
    _updateController = StreamController<Map<String, dynamic>>.broadcast();
    _authController = StreamController<AuthenticationState>.broadcast();
    _fileDownloadController =
        StreamController<FileDownloadComplete>.broadcast();
    _chatEventController = StreamController<ChatEvent>.broadcast();
    _messageEventController = StreamController<MessageEvent>.broadcast();
  }

  /// Stream of file download completion events
  Stream<FileDownloadComplete> get fileDownloads =>
      _fileDownloadController.stream;

  @override
  Future<void> start() async {
    if (_client != null) return; // Already initialized

    _client = TdJsonClient();

    // Set TDLib log verbosity level before any other operations
    _setTdLibLogVerbosity();

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

  @override
  Future<void> setNetworkType({bool isOnline = true}) async {
    await _sendRequest({
      '@type': 'setNetworkType',
      'type': isOnline
          ? {'@type': 'networkTypeOther'}
          : {'@type': 'networkTypeNone'},
    });
    _logger.logResponse({'@type': 'setNetworkType', 'online': isOnline});
  }

  void _startReceiving() {
    _receiveTimer = Timer.periodic(AppConfig.updatePollingInterval, (timer) {
      bool hasUpdates = false;
      while (true) {
        final response = _client!.receive(0.0);
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

    // Check for @extra to complete pending async requests
    final extra = update['@extra'] as String?;
    if (extra != null && _pendingRequests.containsKey(extra)) {
      _pendingRequests.remove(extra)?.complete(update);
      // Response to our request - don't process as a regular update
      // (e.g., getRepliedMessage responses shouldn't be added to chat history)
      return;
    }

    final type = update[TdlibFields.type] as String;

    // Debug log for sticker-related types
    if (type.toLowerCase().contains('sticker')) {
      _logger.logResponse({'@type': 'DEBUG_sticker_type_found', 'type': type});
    }

    if (type == TdlibUpdateTypes.authorizationState) {
      final authState = AuthenticationState.fromJson(
        update['authorization_state'],
      );
      _logger.logAuthState(authState.state.toString());
      _currentAuthState = authState;
      _authController.add(authState);

      _handleAuthorizationState(authState);
    } else if (type == TdlibUpdateTypes.user) {
      _handleUserUpdate(update);
    } else if (type == TdlibUpdateTypes.userStatus) {
      _handleUserStatusUpdate(update);
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
    } else if (type == TdlibUpdateTypes.chatReadOutbox) {
      _handleChatReadOutboxUpdate(update);
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
    } else if (type == TdlibUpdateTypes.messageInteractionInfo) {
      _handleMessageInteractionInfoUpdate(update);
    } else if (type == 'stickerSets' || type == 'StickerSets') {
      _logger.logResponse({
        '@type': 'DEBUG_stickerSets_received',
        'type': type,
        'sets_count': (update['sets'] as List?)?.length,
      });
      _handleStickerSetsResponse(update);
    } else if (type == 'stickerSet' || type == 'StickerSet') {
      _logger.logResponse({'@type': 'DEBUG_stickerSet_received', 'type': type});
      _handleStickerSetResponse(update);
    } else if (type == 'stickers' || type == 'Stickers') {
      _logger.logResponse({'@type': 'DEBUG_stickers_received', 'type': type});
      _handleRecentStickersResponse(update);
    } else if (type == 'availableReactions') {
      _handleAvailableReactionsResponse(update);
    } else if (type == 'error') {
      // Log errors
      _logger.logError('TDLib error: ${update['message']}', error: update);
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

    // For forwarded messages, prefer the original sender name
    final forwardInfo = json['forward_info'] as Map<String, dynamic>?;
    if (forwardInfo != null && senderName == null) {
      final origin = forwardInfo['origin'] as Map<String, dynamic>?;
      if (origin != null) {
        final originType = origin['@type'] as String?;
        if (originType == 'messageOriginChannel') {
          // Get original channel name
          final originChatId = origin['chat_id'] as int?;
          if (originChatId != null) {
            final originChat = _chats[originChatId];
            senderName =
                originChat?.title ?? origin['author_signature'] as String?;
          }
        } else if (originType == 'messageOriginUser') {
          final originUserId = origin['sender_user_id'] as int?;
          if (originUserId != null) {
            senderName = _userNames[originUserId];
          }
        } else if (originType == 'messageOriginHiddenUser') {
          senderName = origin['sender_name'] as String?;
        }
      }
    }

    // For messages with Telegram link previews (e.g., replies to channel posts in discussions),
    // use the link preview title as sender name if it's a t.me link
    final content = json['content'] as Map<String, dynamic>?;
    PhotoInfo? linkPreviewPhoto;
    if (content != null && content['@type'] == 'messageText') {
      final linkPreview = content['link_preview'] as Map<String, dynamic>?;
      if (linkPreview != null) {
        final url = linkPreview['url'] as String? ?? '';
        if (url.contains('t.me/') || url.contains('telegram.me/')) {
          final previewTitle = linkPreview['title'] as String?;
          if (previewTitle != null && previewTitle.isNotEmpty) {
            senderName = previewTitle;
          }
        }

        // Parse link preview photo if available
        final previewType = linkPreview['type'] as Map<String, dynamic>?;
        if (previewType != null &&
            previewType['@type'] == 'linkPreviewTypePhoto') {
          final photoData = previewType['photo'] as Map<String, dynamic>?;
          if (photoData != null) {
            linkPreviewPhoto = _parsePhotoFromSizes(photoData);
          }
        }
      }
    }

    final message = Message.fromJson(
      json,
      senderName: senderName,
      linkPreviewPhoto: linkPreviewPhoto,
    );

    // For cross-chat replies, extract and cache the reply preview from reply_to
    _cacheInlineReplyPreview(json, message.chatId);

    return message;
  }

  /// Cache reply preview data from cross-chat replies (where reply_to contains inline content)
  void _cacheInlineReplyPreview(Map<String, dynamic> json, int messageChatId) {
    final replyTo = json['reply_to'] as Map<String, dynamic>?;
    if (replyTo == null) return;

    final replyChatId = replyTo['chat_id'] as int?;
    final replyMessageId = replyTo['message_id'] as int?;
    if (replyChatId == null || replyMessageId == null) return;

    // Check if this is a cross-chat reply (different chat_id)
    final isCrossChat = replyChatId != messageChatId;
    if (!isCrossChat) return;

    // Already cached?
    final cacheKey = (messageChatId, replyMessageId);
    if (_replyMessageCache.containsKey(cacheKey)) return;

    // Extract sender name from origin
    String? replySenderName;
    final origin = replyTo['origin'] as Map<String, dynamic>?;
    if (origin != null) {
      final originType = origin['@type'] as String?;
      if (originType == 'messageOriginChannel') {
        final originChatId = origin['chat_id'] as int?;
        if (originChatId != null) {
          replySenderName = _chats[originChatId]?.title;
        }
        replySenderName ??= origin['author_signature'] as String?;
      } else if (originType == 'messageOriginUser') {
        final userId = origin['sender_user_id'] as int?;
        if (userId != null) {
          replySenderName = _userNames[userId];
        }
      } else if (originType == 'messageOriginHiddenUser') {
        replySenderName = origin['sender_name'] as String?;
      }
    }

    // Extract content - prefer quote text, fall back to content
    String replyContent = '';
    MessageType replyType = MessageType.text;
    PhotoInfo? replyPhoto;
    PhotoInfo? replyLinkPreviewPhoto;

    // Try to get quote text first
    final quote = replyTo['quote'] as Map<String, dynamic>?;
    if (quote != null) {
      final quoteText = quote['text'] as Map<String, dynamic>?;
      if (quoteText != null) {
        replyContent = quoteText['text'] as String? ?? '';
      }
    }

    // Parse content from reply_to
    final replyToContent = replyTo['content'] as Map<String, dynamic>?;
    if (replyToContent != null) {
      final contentType = replyToContent['@type'] as String?;

      if (contentType == 'messagePhoto') {
        replyType = MessageType.photo;
        if (replyContent.isEmpty) replyContent = '📷 Photo';
        // Parse photo
        final photoData = replyToContent['photo'] as Map<String, dynamic>?;
        if (photoData != null) {
          replyPhoto = _parsePhotoFromSizes(photoData);
        }
      } else if (contentType == 'messageText') {
        // Extract text if we don't have quote
        if (replyContent.isEmpty) {
          final text = replyToContent['text'] as Map<String, dynamic>?;
          replyContent = text?['text'] as String? ?? '';
        }
        // Parse link preview photo
        final linkPreview =
            replyToContent['link_preview'] as Map<String, dynamic>?;
        if (linkPreview != null) {
          // Use link preview title as sender name if not set
          if (replySenderName == null || replySenderName.isEmpty) {
            replySenderName = linkPreview['title'] as String?;
          }
          final previewType = linkPreview['type'] as Map<String, dynamic>?;
          if (previewType != null &&
              previewType['@type'] == 'linkPreviewTypePhoto') {
            final photoData = previewType['photo'] as Map<String, dynamic>?;
            if (photoData != null) {
              replyLinkPreviewPhoto = _parsePhotoFromSizes(photoData);
            }
          }
        }
      } else if (contentType == 'messageVideo') {
        replyType = MessageType.video;
        if (replyContent.isEmpty) replyContent = '🎥 Video';
      } else if (contentType == 'messageSticker') {
        replyType = MessageType.sticker;
        if (replyContent.isEmpty) replyContent = '🎭 Sticker';
      }
    }

    // Create synthetic message for cache
    final syntheticReply = Message(
      id: replyMessageId,
      chatId: replyChatId,
      senderId: replyChatId, // Use chat ID as sender for channels
      senderName: replySenderName ?? 'Channel',
      date: DateTime.now(), // Not critical for preview
      content: replyContent,
      isOutgoing: false,
      type: replyType,
      photo: replyPhoto,
      linkPreviewPhoto: replyLinkPreviewPhoto,
    );

    _replyMessageCache[cacheKey] = syntheticReply;
    _logger.logRequest({
      '@type': 'cross_chat_reply_cached',
      'cache_key': '($messageChatId, $replyMessageId)',
      'sender_name': replySenderName,
      'content_preview': replyContent.substring(
        0,
        replyContent.length.clamp(0, 50),
      ),
      'has_photo': replyPhoto != null,
      'has_link_preview_photo': replyLinkPreviewPhoto != null,
    });

    // Trigger photo downloads if needed
    if (replyPhoto != null &&
        replyPhoto.path == null &&
        replyPhoto.fileId != null) {
      _photoFileToMessage[replyPhoto.fileId!] = (
        chatId: messageChatId,
        messageId: replyMessageId,
      );
      downloadFile(replyPhoto.fileId!);
    }
    if (replyLinkPreviewPhoto != null &&
        replyLinkPreviewPhoto.path == null &&
        replyLinkPreviewPhoto.fileId != null) {
      _photoFileToMessage[replyLinkPreviewPhoto.fileId!] = (
        chatId: messageChatId,
        messageId: replyMessageId,
      );
      downloadFile(replyLinkPreviewPhoto.fileId!);
    }
  }

  /// Parse photo from TDLib photo data (message photos, link previews, etc.)
  /// Prefers 'm' size (~320px) for thumbnails, falls back to first available.
  PhotoInfo? _parsePhotoFromSizes(Map<String, dynamic> photoData) {
    final sizes = photoData['sizes'] as List?;
    if (sizes == null || sizes.isEmpty) return null;

    Map<String, dynamic>? bestSize;
    for (final size in sizes) {
      if (size is Map<String, dynamic>) {
        final sizeType = size['type'] as String?;
        if (sizeType == 'm') {
          bestSize = size;
          break;
        }
        bestSize ??= size;
      }
    }

    if (bestSize == null) return null;

    final fileInfo = bestSize['photo'] as Map<String, dynamic>?;
    final localPath = fileInfo?['local']?['path'] as String?;

    return PhotoInfo(
      path: (localPath?.isNotEmpty == true) ? localPath : null,
      fileId: fileInfo?['id'] as int?,
      width: bestSize['width'] as int?,
      height: bestSize['height'] as int?,
    );
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

  void _handleUserStatusUpdate(Map<String, dynamic> update) {
    try {
      final userId = update['user_id'] as int?;
      final status = update['status'] as Map<String, dynamic>?;

      if (userId == null || status == null) return;

      final statusType = status[TdlibFields.type] as String?;
      if (statusType == null) return;

      String statusString;
      DateTime? lastSeen;

      switch (statusType) {
        case TdlibUserStatusTypes.online:
          statusString = 'online';
        case TdlibUserStatusTypes.offline:
          final wasOnline = status['was_online'] as int?;
          if (wasOnline != null) {
            lastSeen = DateTime.fromMillisecondsSinceEpoch(wasOnline * 1000);
            statusString = _formatLastSeen(lastSeen);
          } else {
            statusString = 'offline';
          }
        case TdlibUserStatusTypes.recently:
          statusString = 'last seen recently';
        case TdlibUserStatusTypes.lastWeek:
          statusString = 'last seen within a week';
        case TdlibUserStatusTypes.lastMonth:
          statusString = 'last seen within a month';
        case TdlibUserStatusTypes.empty:
          statusString = '';
        default:
          statusString = '';
      }

      // Cache the status
      _userStatuses[userId] = statusString;

      _logger.logRequest({
        '@type': 'user_status_updated',
        'user_id': userId,
        'status': statusString,
      });

      // Emit event for UI updates
      _chatEventController.add(
        UserStatusUpdatedEvent(userId, statusString, lastSeen: lastSeen),
      );
    } catch (e) {
      _logger.logError('Error processing updateUserStatus', error: e);
    }
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);

    if (diff.inMinutes < 1) {
      return 'last seen just now';
    } else if (diff.inMinutes < 60) {
      return 'last seen ${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return 'last seen ${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'last seen yesterday';
    } else if (diff.inDays < 7) {
      return 'last seen ${diff.inDays} days ago';
    } else {
      return 'last seen within a week';
    }
  }

  /// Get cached user status
  @override
  String? getUserStatus(int userId) => _userStatuses[userId];

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
      _chatEventController.add(
        ChatUnreadCountUpdatedEvent(chatId, unreadCount),
      );
    }
  }

  void _handleChatReadOutboxUpdate(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final lastReadOutboxMessageId =
        update['last_read_outbox_message_id'] as int?;

    if (chatId != null && lastReadOutboxMessageId != null) {
      // Emit typed event for message state updates
      _messageEventController.add(
        ChatReadOutboxEvent(chatId, lastReadOutboxMessageId),
      );
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
    _chatEventController.add(
      ChatPositionChangedEvent(chatId, hasValidPosition),
    );
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
    if (Platform.isAndroid || Platform.isIOS) {
      final appDir = await getApplicationDocumentsDirectory();
      return path.join(appDir.path, 'tdlib');
    }
    final homeDir = Platform.environment['HOME'] ?? '';
    final dbPath = path.join(
      homeDir,
      '.local',
      'share',
      'telegram_flutter_client',
    );
    return dbPath;
  }

  Future<Map<String, dynamic>?> _sendRequest(
    Map<String, dynamic> request,
  ) async {
    _logger.logRequest(request);
    final requestJson = jsonEncode(request);
    _client!.send(requestJson);
    return null;
  }

  /// Send a request and wait for the actual response using @extra correlation.
  /// Use this for requests where you need the response data.
  Future<Map<String, dynamic>?> _sendRequestAsync(
    Map<String, dynamic> request, {
    Duration? timeout,
  }) async {
    final requestId = 'req_${++_requestId}';
    final completer = Completer<Map<String, dynamic>?>();
    _pendingRequests[requestId] = completer;

    // Add @extra for response correlation
    final requestWithExtra = {...request, '@extra': requestId};
    _logger.logRequest(requestWithExtra);
    final requestJson = jsonEncode(requestWithExtra);
    _client!.send(requestJson);

    // Wait for response with timeout
    try {
      final response = await completer.future.timeout(
        timeout ?? const Duration(seconds: 5),
        onTimeout: () {
          _pendingRequests.remove(requestId);
          return null;
        },
      );
      return response;
    } catch (e) {
      _pendingRequests.remove(requestId);
      return null;
    }
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
    await _sendRequest({'@type': 'checkAuthenticationCode', 'code': code});
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
    await _sendRequest({'@type': 'confirmQrCodeAuthentication', 'link': link});
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
    await _sendRequest({'@type': 'resendAuthenticationCode'});
  }

  @override
  Future<void> logOut() async {
    await _sendRequest({'@type': 'logOut'});
  }

  @override
  Future<List<Chat>> loadChats({
    int limit = 20,
    int offsetOrder = 0,
    int offsetChatId = 0,
  }) async {
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
    await _sendRequest({'@type': 'getChat', 'chat_id': chatId});

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
      _client!.execute(request);

      _logger.logConnectionState(
        'Log verbosity set to level ${logLevel.level} (${logLevel.description})',
      );
    } catch (e) {
      _logger.logError('Failed to set TDLib log verbosity', error: e);
    }
  }

  @override
  Future<List<Message>> loadMessages(
    int chatId, {
    int limit = 50,
    int fromMessageId = 0,
  }) async {
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
      final minMessages = fromMessageId == 0
          ? AppConfig.minCachedMessages
          : limit;
      return await _loadMessagesRecursively(chatId, minMessages, fromMessageId);
    } catch (e) {
      _logger.logError('Failed to load messages for chat $chatId', error: e);
      return _messages[chatId] ?? [];
    }
  }

  Future<List<Message>> _loadMessagesRecursively(
    int chatId,
    int minMessages,
    int fromMessageId, {
    int? maxAttempts,
  }) async {
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
      final oldestMessage = currentMessages.reduce(
        (a, b) => a.date.isBefore(b.date) ? a : b,
      );
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
  Future<Message?> getMessage(int chatId, int messageId) async {
    try {
      final response = await _sendRequest({
        '@type': 'getMessage',
        'chat_id': chatId,
        'message_id': messageId,
      });

      if (response == null || response['@type'] == 'error') {
        _logger.logError(
          'Failed to get message $messageId in chat $chatId',
          error: response?['message'],
        );
        return null;
      }

      if (response['@type'] == 'message') {
        return _createMessageFromJson(response);
      }

      return null;
    } catch (e) {
      _logger.logError(
        'Failed to get message $messageId in chat $chatId',
        error: e,
      );
      return null;
    }
  }

  /// Get a reply message - checks cache first, fetches from server if needed.
  /// Returns cached message synchronously if available.
  @override
  Message? getCachedReplyMessage(int chatId, int messageId) {
    // Check message cache first
    final messages = _messages[chatId];
    if (messages != null) {
      final cached = messages.cast<Message?>().firstWhere(
        (m) => m?.id == messageId,
        orElse: () => null,
      );
      if (cached != null) return cached;
    }
    // Check reply cache
    return _replyMessageCache[(chatId, messageId)];
  }

  /// Fetch a reply message if not already cached or pending.
  /// Uses getRepliedMessage TDLib API which properly fetches from server.
  /// messageId is the ID of the message that has the reply.
  /// replyToMessageId is the ID of the message being replied to (for caching).
  @override
  Future<Message?> fetchReplyMessage(
    int chatId,
    int messageId,
    int replyToMessageId,
  ) async {
    final key = (chatId, replyToMessageId);

    // Already cached?
    final cached = getCachedReplyMessage(chatId, replyToMessageId);
    if (cached != null) return cached;

    // Already fetching?
    if (_pendingReplyFetches.contains(key)) return null;

    _pendingReplyFetches.add(key);
    try {
      // Use getRepliedMessage with async response
      final response = await _sendRequestAsync({
        '@type': 'getRepliedMessage',
        'chat_id': chatId,
        'message_id': messageId,
      });

      if (response == null || response['@type'] == 'error') {
        _logger.logError(
          'Failed to get replied message for $messageId in chat $chatId: ${response?['message']}',
        );
        return null;
      }

      if (response['@type'] == 'message') {
        final message = _createMessageFromJson(response);
        _logger.logRequest({
          '@type': 'reply_message_resolved',
          'sender_name': message.senderName,
          'sender_id': message.senderId,
          'content_preview': message.content.substring(
            0,
            message.content.length.clamp(0, 50),
          ),
          'has_photo': message.photo != null,
          'has_link_preview_photo': message.linkPreviewPhoto != null,
        });
        _replyMessageCache[key] = message;

        // Trigger download for photos in reply messages
        if (message.photo != null &&
            message.photo!.path == null &&
            message.photo!.fileId != null) {
          _photoFileToMessage[message.photo!.fileId!] = (
            chatId: chatId,
            messageId: replyToMessageId,
          );
          downloadFile(message.photo!.fileId!);
        }
        // Trigger download for link preview photos
        if (message.linkPreviewPhoto != null &&
            message.linkPreviewPhoto!.path == null &&
            message.linkPreviewPhoto!.fileId != null) {
          _photoFileToMessage[message.linkPreviewPhoto!.fileId!] = (
            chatId: chatId,
            messageId: replyToMessageId,
          );
          downloadFile(message.linkPreviewPhoto!.fileId!);
        }

        return message;
      }

      return null;
    } finally {
      _pendingReplyFetches.remove(key);
    }
  }

  @override
  Future<Message?> sendMessage(
    int chatId,
    String text, {
    int? replyToMessageId,
  }) async {
    try {
      final request = {
        '@type': 'sendMessage',
        'chat_id': chatId,
        if (replyToMessageId != null)
          'reply_to': {
            '@type': 'inputMessageReplyToMessage',
            'message_id': replyToMessageId,
          },
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
  Future<void> sendPhoto(
    int chatId,
    String filePath, {
    String? caption,
    int? replyToMessageId,
  }) async {
    try {
      final request = {
        '@type': 'sendMessage',
        'chat_id': chatId,
        if (replyToMessageId != null)
          'reply_to': {
            '@type': 'inputMessageReplyToMessage',
            'message_id': replyToMessageId,
          },
        'input_message_content': {
          '@type': 'inputMessagePhoto',
          'photo': {'@type': 'inputFileLocal', 'path': filePath},
          if (caption != null && caption.isNotEmpty)
            'caption': {'@type': 'formattedText', 'text': caption},
        },
      };

      await _sendRequest(request);
    } catch (e) {
      _logger.logError('Failed to send photo to chat $chatId', error: e);
      rethrow;
    }
  }

  @override
  Future<void> sendVideo(
    int chatId,
    String filePath, {
    String? caption,
    int? replyToMessageId,
  }) async {
    try {
      final request = {
        '@type': 'sendMessage',
        'chat_id': chatId,
        if (replyToMessageId != null)
          'reply_to': {
            '@type': 'inputMessageReplyToMessage',
            'message_id': replyToMessageId,
          },
        'input_message_content': {
          '@type': 'inputMessageVideo',
          'video': {'@type': 'inputFileLocal', 'path': filePath},
          if (caption != null && caption.isNotEmpty)
            'caption': {'@type': 'formattedText', 'text': caption},
        },
      };

      await _sendRequest(request);
    } catch (e) {
      _logger.logError('Failed to send video to chat $chatId', error: e);
      rethrow;
    }
  }

  @override
  Future<void> sendDocument(
    int chatId,
    String filePath, {
    String? caption,
    int? replyToMessageId,
  }) async {
    try {
      final request = {
        '@type': 'sendMessage',
        'chat_id': chatId,
        if (replyToMessageId != null)
          'reply_to': {
            '@type': 'inputMessageReplyToMessage',
            'message_id': replyToMessageId,
          },
        'input_message_content': {
          '@type': 'inputMessageDocument',
          'document': {'@type': 'inputFileLocal', 'path': filePath},
          if (caption != null && caption.isNotEmpty)
            'caption': {'@type': 'formattedText', 'text': caption},
        },
      };

      await _sendRequest(request);
    } catch (e) {
      _logger.logError('Failed to send document to chat $chatId', error: e);
      rethrow;
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
      _logger.logError(
        'Failed to mark message as read in chat $chatId',
        error: e,
      );
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
      _logger.logError(
        'Failed to delete message $messageId in chat $chatId',
        error: e,
      );
      return false;
    }
  }

  @override
  Future<Message?> editMessage(
    int chatId,
    int messageId,
    String newText,
  ) async {
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
      _logger.logError(
        'Failed to edit message $messageId in chat $chatId',
        error: e,
      );
      return null;
    }
  }

  @override
  Future<void> forwardMessages(
    int fromChatId,
    int toChatId,
    List<int> messageIds,
  ) async {
    try {
      await _sendRequest({
        '@type': 'forwardMessages',
        'chat_id': toChatId,
        'from_chat_id': fromChatId,
        'message_ids': messageIds,
        'send_copy': false,
        'remove_caption': false,
      });
      _logger.logResponse({
        '@type': 'forwardMessages_success',
        'count': messageIds.length,
        'from': fromChatId,
        'to': toChatId,
      });
    } catch (e) {
      _logger.logError(
        'Failed to forward messages from $fromChatId to $toChatId',
        error: e,
      );
      rethrow;
    }
  }

  @override
  Future<List<String>> getAvailableReactions(int chatId, int messageId) async {
    try {
      // If there's already a pending request, reuse it
      if (_availableReactionsCompleter != null &&
          !_availableReactionsCompleter!.isCompleted) {
        return _availableReactionsCompleter!.future;
      }

      _availableReactionsCompleter = Completer<List<String>>();

      _logger.logRequest({
        '@type': 'getMessageAvailableReactions',
        'chat_id': chatId,
        'message_id': messageId,
      });

      await _sendRequest({
        '@type': 'getMessageAvailableReactions',
        'chat_id': chatId,
        'message_id': messageId,
        'row_size': 8,
      });

      // Wait for response with timeout
      final result = await _availableReactionsCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => <String>[],
      );

      _logger.logResponse({
        '@type': 'getMessageAvailableReactions_result',
        'count': result.length,
        'emojis': result.take(5).toList(),
      });

      return result;
    } catch (e) {
      _logger.logError('Failed to get available reactions', error: e);
      return [];
    }
  }

  void _handleAvailableReactionsResponse(Map<String, dynamic> update) {
    try {
      final emojis = <String>[];

      // Helper to extract emojis from reaction list
      void extractEmojis(List<dynamic>? reactions) {
        if (reactions == null) return;
        for (final reaction in reactions) {
          // Skip premium reactions
          if (reaction['needs_premium'] == true) continue;

          final type = reaction['type'] as Map<String, dynamic>?;
          if (type == null) continue;

          // Only handle emoji reactions (not custom emoji or paid)
          if (type['@type'] == 'reactionTypeEmoji') {
            final emoji = type['emoji'] as String?;
            if (emoji != null && !emojis.contains(emoji)) {
              emojis.add(emoji);
            }
          }
        }
      }

      extractEmojis(update['top_reactions'] as List<dynamic>?);
      extractEmojis(update['recent_reactions'] as List<dynamic>?);
      extractEmojis(update['popular_reactions'] as List<dynamic>?);

      if (_availableReactionsCompleter != null &&
          !_availableReactionsCompleter!.isCompleted) {
        _availableReactionsCompleter!.complete(emojis);
      }
    } catch (e) {
      _logger.logError('Error handling available reactions response', error: e);
      if (_availableReactionsCompleter != null &&
          !_availableReactionsCompleter!.isCompleted) {
        _availableReactionsCompleter!.complete([]);
      }
    }
  }

  @override
  Future<void> addReaction(
    int chatId,
    int messageId,
    MessageReaction reaction,
  ) async {
    _logger.logRequest({
      '@type': 'addReaction_called',
      'chat_id': chatId,
      'message_id': messageId,
      'reaction_type': reaction.type.toString(),
      'emoji': reaction.emoji,
    });

    try {
      Map<String, dynamic> reactionType;
      switch (reaction.type) {
        case ReactionType.emoji:
          reactionType = {
            '@type': 'reactionTypeEmoji',
            'emoji': reaction.emoji,
          };
        case ReactionType.customEmoji:
          reactionType = {
            '@type': 'reactionTypeCustomEmoji',
            'custom_emoji_id': reaction.customEmojiId,
          };
        case ReactionType.paid:
          reactionType = {'@type': 'reactionTypePaid'};
      }

      final response = await _sendRequest({
        '@type': 'addMessageReaction',
        'chat_id': chatId,
        'message_id': messageId,
        'reaction_type': reactionType,
        'is_big': false,
        'update_recent_reactions': true,
      });

      _logger.logResponse({
        '@type': 'addReaction_response',
        'response': response?.toString(),
      });
    } catch (e) {
      _logger.logError(
        'Failed to add reaction to message $messageId in chat $chatId',
        error: e,
      );
      rethrow;
    }
  }

  @override
  Future<void> removeReaction(
    int chatId,
    int messageId,
    MessageReaction reaction,
  ) async {
    try {
      Map<String, dynamic> reactionType;
      switch (reaction.type) {
        case ReactionType.emoji:
          reactionType = {
            '@type': 'reactionTypeEmoji',
            'emoji': reaction.emoji,
          };
        case ReactionType.customEmoji:
          reactionType = {
            '@type': 'reactionTypeCustomEmoji',
            'custom_emoji_id': reaction.customEmojiId,
          };
        case ReactionType.paid:
          reactionType = {'@type': 'reactionTypePaid'};
      }

      await _sendRequest({
        '@type': 'removeMessageReaction',
        'chat_id': chatId,
        'message_id': messageId,
        'reaction_type': reactionType,
      });
    } catch (e) {
      _logger.logError(
        'Failed to remove reaction from message $messageId in chat $chatId',
        error: e,
      );
      rethrow;
    }
  }

  /// Adds a message to the cache for a chat.
  /// [insertAtStart] - if true, inserts at beginning (for new incoming messages)
  ///                   if false, appends at end (for batch history loading)
  void _addMessageToCache(
    int chatId,
    Message message, {
    bool insertAtStart = false,
  }) {
    if (!_messages.containsKey(chatId)) {
      _messages[chatId] = <Message>[];
    }

    // Process custom emojis in reactions if present
    var processedMessage = message;
    if (message.reactions != null && message.reactions!.isNotEmpty) {
      final processedReactions = _processCustomEmojiReactions(
        chatId,
        message.id,
        message.reactions!,
      );
      processedMessage = message.copyWith(reactions: processedReactions);
    }

    final existingIndex = _messages[chatId]!.indexWhere(
      (msg) => msg.id == processedMessage.id,
    );
    if (existingIndex != -1) {
      _messages[chatId]![existingIndex] = processedMessage;
    } else {
      if (insertAtStart) {
        _messages[chatId]!.insert(0, processedMessage);
      } else {
        _messages[chatId]!.add(processedMessage);
      }
    }

    // Track photo file ID for download completion updates
    if (processedMessage.photo?.fileId != null) {
      _photoFileToMessage[processedMessage.photo!.fileId!] = (
        chatId: chatId,
        messageId: processedMessage.id,
      );
    }

    // Track sticker file ID for download completion updates
    if (processedMessage.sticker?.fileId != null) {
      _stickerFileToMessage[processedMessage.sticker!.fileId!] = (
        chatId: chatId,
        messageId: processedMessage.id,
      );
    }

    // Track video file ID for download completion updates
    if (processedMessage.video?.fileId != null) {
      _videoFileToMessage[processedMessage.video!.fileId!] = (
        chatId: chatId,
        messageId: processedMessage.id,
      );
    }
  }

  /// Removes a message from the cache by ID.
  void _removeMessageFromCache(int chatId, int messageId) {
    if (!_messages.containsKey(chatId)) return;
    _messages[chatId]!.removeWhere((msg) => msg.id == messageId);
  }

  void _handleMessageUpdate(Map<String, dynamic> update) {
    try {
      // Handle both wrapped (updateNewMessage) and direct (getMessage) responses
      final message =
          update['message'] as Map<String, dynamic>? ??
          (update['@type'] == 'message' ? update : null);
      if (message == null) return;

      final chatId = message['chat_id'] as int?;
      if (chatId == null) return;

      final messageObj = _createMessageFromJson(message);
      _addMessageToCache(chatId, messageObj, insertAtStart: true);

      // Keep only the most recent messages per chat
      if (_messages[chatId]!.length > AppConfig.maxMessagesPerChat) {
        _messages[chatId] = _messages[chatId]!
            .take(AppConfig.maxMessagesPerChat)
            .toList();
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
      _messageEventController.add(
        MessageContentChangedEvent(chatId, messageId, newContent),
      );
    } catch (e) {
      _logger.logError('Error handling message content update', error: e);
    }
  }

  void _handleMessageSendSucceededUpdate(Map<String, dynamic> update) {
    try {
      final messageData = update['message'] as Map<String, dynamic>?;
      if (messageData == null) return;

      final oldMessageId = update['old_message_id'] as int? ?? 0;
      final message = _createMessageFromJson(messageData);
      final chatId = message.chatId;

      // Update cache - remove old temp message, add new one
      _removeMessageFromCache(chatId, oldMessageId);
      _addMessageToCache(chatId, message, insertAtStart: false);

      // Emit typed event with old message ID for replacement
      _messageEventController.add(
        MessageSendSucceededEvent(chatId, message, oldMessageId),
      );
    } catch (e) {
      _logger.logError(
        'Error handling message send succeeded update',
        error: e,
      );
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

  void _handleMessageInteractionInfoUpdate(Map<String, dynamic> update) {
    try {
      final chatId = update['chat_id'] as int?;
      final messageId = update['message_id'] as int?;
      final interactionInfo =
          update['interaction_info'] as Map<String, dynamic>?;

      _logger.logRequest({
        '@type': 'interaction_info_update_received',
        'chat_id': chatId,
        'message_id': messageId,
        'has_interaction_info': interactionInfo != null,
      });

      if (chatId == null || messageId == null) return;

      // Parse reactions from interaction_info
      List<MessageReaction>? reactions;
      if (interactionInfo != null) {
        final reactionsData =
            interactionInfo['reactions'] as Map<String, dynamic>?;
        if (reactionsData != null) {
          final reactionsList = reactionsData['reactions'] as List<dynamic>?;
          if (reactionsList != null && reactionsList.isNotEmpty) {
            reactions = reactionsList
                .whereType<Map<String, dynamic>>()
                .map((r) => MessageReaction.fromJson(r))
                .toList();
          }
        }
      }

      // Process custom emoji reactions - apply cached paths and fetch missing ones
      if (reactions != null) {
        reactions = _processCustomEmojiReactions(chatId, messageId, reactions);
      }

      // Update cached message if exists
      final cachedMessages = _messages[chatId];
      if (cachedMessages != null) {
        final idx = cachedMessages.indexWhere((m) => m.id == messageId);
        if (idx != -1) {
          final updatedMessage = cachedMessages[idx].copyWith(
            reactions: reactions,
          );
          cachedMessages[idx] = updatedMessage;
        }
      }

      // Emit typed event
      _logger.logRequest({
        '@type': 'emitting_reactions_event',
        'chat_id': chatId,
        'message_id': messageId,
        'reactions_count': reactions?.length ?? 0,
      });
      _messageEventController.add(
        MessageReactionsUpdatedEvent(chatId, messageId, reactions ?? []),
      );
    } catch (e) {
      _logger.logError(
        'Error handling message interaction info update',
        error: e,
      );
    }
  }

  /// Process custom emoji reactions - apply cached paths and trigger fetches for missing ones
  List<MessageReaction> _processCustomEmojiReactions(
    int chatId,
    int messageId,
    List<MessageReaction> reactions,
  ) {
    final customEmojiIdsToFetch = <int>[];

    final processedReactions = reactions.map((reaction) {
      if (reaction.type == ReactionType.customEmoji &&
          reaction.customEmojiId != null) {
        final emojiId = reaction.customEmojiId!;

        // Track which messages use this custom emoji
        _customEmojiToMessages.putIfAbsent(emojiId, () => {});
        _customEmojiToMessages[emojiId]!.add((
          chatId: chatId,
          messageId: messageId,
        ));

        // Check if we have cached path
        final cachedPath = _customEmojiCache[emojiId];
        if (cachedPath != null) {
          return reaction.copyWith(customEmojiPath: cachedPath);
        }

        // Need to fetch this custom emoji
        if (!_pendingCustomEmojiFetches.contains(emojiId) &&
            !_customEmojiFileIds.containsKey(emojiId)) {
          customEmojiIdsToFetch.add(emojiId);
        }
      }
      return reaction;
    }).toList();

    // Fetch missing custom emojis
    if (customEmojiIdsToFetch.isNotEmpty) {
      _fetchCustomEmojis(customEmojiIdsToFetch);
    }

    return processedReactions;
  }

  /// Fetch custom emoji stickers from TDLib
  Future<void> _fetchCustomEmojis(List<int> customEmojiIds) async {
    // Mark as pending to avoid duplicate fetches
    _pendingCustomEmojiFetches.addAll(customEmojiIds);

    _logger.logRequest({
      '@type': 'fetching_custom_emojis',
      'emoji_ids': customEmojiIds,
    });

    try {
      final response = await _sendRequest({
        '@type': 'getCustomEmojiStickers',
        'custom_emoji_ids': customEmojiIds,
      });

      _logger.logResponse({
        '@type': 'custom_emoji_response',
        'response': response?.toString(),
      });

      if (response == null) return;
      final stickers = response['stickers'] as List<dynamic>?;
      if (stickers == null) {
        _logger.logError('No stickers in response', error: response);
        return;
      }

      _logger.logRequest({
        '@type': 'custom_emoji_stickers_count',
        'count': stickers.length,
      });

      for (final sticker in stickers) {
        if (sticker is! Map<String, dynamic>) continue;

        _logger.logResponse({
          '@type': 'custom_emoji_sticker_data',
          'sticker_keys': sticker.keys.toList(),
        });

        // The custom_emoji_id is at the top level of the sticker object
        final customEmojiId = sticker['custom_emoji_id'] as int?;
        if (customEmojiId == null) {
          _logger.logError('No custom_emoji_id in sticker', error: sticker);
          continue;
        }

        // Get the sticker file info - it's in 'sticker' field
        final stickerFile = sticker['sticker'] as Map<String, dynamic>?;
        if (stickerFile == null) {
          _logger.logError('No sticker file in sticker object', error: sticker);
          continue;
        }

        final fileId = stickerFile['id'] as int?;
        if (fileId == null) {
          _logger.logError('No file id in sticker file', error: stickerFile);
          continue;
        }

        // Check if already downloaded
        final localPath = stickerFile['local']?['path'] as String?;
        _logger.logRequest({
          '@type': 'custom_emoji_file_status',
          'custom_emoji_id': customEmojiId,
          'file_id': fileId,
          'local_path': localPath,
        });

        if (localPath != null && localPath.isNotEmpty) {
          // Already downloaded - cache and notify
          _customEmojiCache[customEmojiId] = localPath;
          _updateMessagesWithCustomEmoji(customEmojiId, localPath);
        } else {
          // Need to download
          _customEmojiFileIds[customEmojiId] = fileId;
          _fileIdToCustomEmoji[fileId] = customEmojiId;
          _logger.logRequest({
            '@type': 'downloading_custom_emoji',
            'custom_emoji_id': customEmojiId,
            'file_id': fileId,
          });
          downloadFile(fileId);
        }
      }
    } catch (e) {
      _logger.logError('Error fetching custom emojis', error: e);
    } finally {
      _pendingCustomEmojiFetches.removeAll(customEmojiIds);
    }
  }

  /// Update all messages that use a custom emoji when it's downloaded
  void _updateMessagesWithCustomEmoji(int customEmojiId, String path) {
    final messageRefs = _customEmojiToMessages[customEmojiId];
    if (messageRefs == null || messageRefs.isEmpty) return;

    for (final ref in messageRefs) {
      final cachedMessages = _messages[ref.chatId];
      if (cachedMessages == null) continue;

      final idx = cachedMessages.indexWhere((m) => m.id == ref.messageId);
      if (idx == -1) continue;

      final message = cachedMessages[idx];
      if (message.reactions == null) continue;

      // Update the reaction with the downloaded path
      final updatedReactions = message.reactions!.map((r) {
        if (r.type == ReactionType.customEmoji &&
            r.customEmojiId == customEmojiId) {
          return r.copyWith(customEmojiPath: path);
        }
        return r;
      }).toList();

      final updatedMessage = message.copyWith(reactions: updatedReactions);
      cachedMessages[idx] = updatedMessage;

      // Emit update event
      _messageEventController.add(
        MessageReactionsUpdatedEvent(
          ref.chatId,
          ref.messageId,
          updatedReactions,
        ),
      );
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

      if (isComplete &&
          fileId != null &&
          filePath != null &&
          filePath.isNotEmpty) {
        _logger.logRequest({
          '@type': 'file_download_completed',
          'file_id': fileId,
          'path': filePath,
        });

        // Cache the downloaded file path
        _stickerFileCache[fileId] = filePath;
        _pendingDownloads.remove(fileId);

        // Emit event for completed download
        _fileDownloadController.add(FileDownloadComplete(fileId, filePath));

        // Update any chats that have this file ID as their photo
        _updateChatPhotoByFileId(fileId, filePath);

        // Update any messages that have this file ID as their photo
        _updateMessagePhotoByFileId(fileId, filePath);

        // Update any messages that have this file ID as their sticker
        _updateMessageStickerByFileId(fileId, filePath);

        // Update any messages that have this file ID as their video
        _updateMessageVideoByFileId(fileId, filePath);

        // Update any custom emojis that have this file ID
        _updateCustomEmojiByFileId(fileId, filePath);
      }
    } catch (e) {
      _logger.logError('Error handling file update', error: e);
    }
  }

  void _updateCustomEmojiByFileId(int fileId, String path) {
    final customEmojiId = _fileIdToCustomEmoji[fileId];
    if (customEmojiId == null) return;

    _logger.logRequest({
      '@type': 'custom_emoji_download_complete',
      'file_id': fileId,
      'custom_emoji_id': customEmojiId,
      'path': path,
    });

    // Cache the path
    _customEmojiCache[customEmojiId] = path;

    // Clean up mappings
    _fileIdToCustomEmoji.remove(fileId);
    _customEmojiFileIds.remove(customEmojiId);

    // Update all messages using this custom emoji
    _updateMessagesWithCustomEmoji(customEmojiId, path);
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

    bool updated = false;

    // Try to update message in main messages cache
    final messages = _messages[chatId];
    if (messages != null) {
      final index = messages.indexWhere((m) => m.id == messageId);
      if (index != -1) {
        final existingPhoto = messages[index].photo;
        if (existingPhoto != null) {
          final updatedMessage = messages[index].copyWith(
            photo: existingPhoto.copyWith(path: path),
          );
          messages[index] = updatedMessage;
          updated = true;
        }
      }
    }

    // Also update reply message cache (for both photo and linkPreviewPhoto)
    final replyKey = (chatId, messageId);
    final cachedReply = _replyMessageCache[replyKey];
    if (cachedReply != null) {
      Message? updatedReply;
      // Update regular photo if it matches
      if (cachedReply.photo?.fileId == fileId) {
        updatedReply = cachedReply.copyWith(
          photo: cachedReply.photo!.copyWith(path: path),
        );
      }
      // Update link preview photo if it matches
      if (cachedReply.linkPreviewPhoto?.fileId == fileId) {
        updatedReply = (updatedReply ?? cachedReply).copyWith(
          linkPreviewPhoto: cachedReply.linkPreviewPhoto!.copyWith(path: path),
        );
      }
      if (updatedReply != null) {
        _replyMessageCache[replyKey] = updatedReply;
        updated = true;
        _logger.logRequest({
          '@type': 'reply_photo_updated',
          'chat_id': chatId,
          'message_id': messageId,
          'file_id': fileId,
          'path': path,
        });
      }
    }

    if (updated) {
      _logger.logRequest({
        '@type': 'message_photo_updated',
        'chat_id': chatId,
        'message_id': messageId,
        'file_id': fileId,
        'path': path,
      });

      // Emit typed event for presentation layer
      _messageEventController.add(
        MessagePhotoUpdatedEvent(chatId, messageId, path),
      );
    }

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

    final existingSticker = messages[index].sticker;
    if (existingSticker == null) return;
    final updatedMessage = messages[index].copyWith(
      sticker: existingSticker.copyWith(path: path),
    );
    messages[index] = updatedMessage;

    _logger.logRequest({
      '@type': 'message_sticker_updated',
      'chat_id': chatId,
      'message_id': messageId,
      'file_id': fileId,
      'path': path,
    });

    // Emit typed event for presentation layer
    _messageEventController.add(
      MessageStickerUpdatedEvent(chatId, messageId, path),
    );

    // Clean up tracking
    _stickerFileToMessage.remove(fileId);
  }

  void _updateMessageVideoByFileId(int fileId, String path) {
    final messageInfo = _videoFileToMessage[fileId];
    if (messageInfo == null) return;

    final chatId = messageInfo.chatId;
    final messageId = messageInfo.messageId;

    // Find and update the message in cache
    final messages = _messages[chatId];
    if (messages == null) return;

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final existingVideo = messages[index].video;
    if (existingVideo == null) return;
    final updatedMessage = messages[index].copyWith(
      video: existingVideo.copyWith(path: path),
    );
    messages[index] = updatedMessage;

    _logger.logRequest({
      '@type': 'message_video_updated',
      'chat_id': chatId,
      'message_id': messageId,
      'file_id': fileId,
      'path': path,
    });

    // Emit typed event for presentation layer
    _messageEventController.add(
      MessageVideoUpdatedEvent(chatId, messageId, path),
    );

    // Clean up tracking
    _videoFileToMessage.remove(fileId);
  }

  /// Get cached sticker file path if available
  String? getCachedStickerPath(int fileId) {
    return _stickerFileCache[fileId];
  }

  @override
  Future<void> downloadFile(int fileId) async {
    // Check cache first - if already downloaded, emit event immediately
    final cachedPath = _stickerFileCache[fileId];
    if (cachedPath != null) {
      _fileDownloadController.add(FileDownloadComplete(fileId, cachedPath));
      return;
    }

    // Skip if download already in progress
    if (_pendingDownloads.contains(fileId)) {
      return;
    }

    // Track this download as pending
    _pendingDownloads.add(fileId);

    await _sendRequest({
      '@type': 'downloadFile',
      'file_id': fileId,
      'priority': 1,
      'synchronous': false,
    });
  }

  // Available reactions completer
  Completer<List<String>>? _availableReactionsCompleter;

  // Sticker methods

  final Map<int, StickerSet> _stickerSetsCache = {};
  final List<StickerSet> _installedStickerSets = [];
  Completer<List<StickerSet>>? _stickerSetsCompleter;
  Completer<StickerSet>? _stickerSetCompleter;
  Completer<List<Sticker>>? _recentStickersCompleter;

  @override
  Future<List<StickerSet>> getInstalledStickerSets() async {
    _logger.logRequest({'@type': 'DEBUG_getInstalledStickerSets_called'});

    // Return cached if available
    if (_installedStickerSets.isNotEmpty) {
      _logger.logRequest({
        '@type': 'DEBUG_returning_cached',
        'count': _installedStickerSets.length,
      });
      return _installedStickerSets;
    }

    // If there's already a pending request, reuse it instead of creating a new one
    if (_stickerSetsCompleter != null && !_stickerSetsCompleter!.isCompleted) {
      _logger.logRequest({'@type': 'DEBUG_reusing_pending_request'});
      return _stickerSetsCompleter!.future;
    }

    _stickerSetsCompleter = Completer<List<StickerSet>>();

    _logger.logRequest({'@type': 'DEBUG_sending_getInstalledStickerSets'});
    await _sendRequest({
      '@type': 'getInstalledStickerSets',
      'sticker_type': {'@type': 'stickerTypeRegular'},
    });

    // Wait for response with timeout
    try {
      _logger.logRequest({'@type': 'DEBUG_waiting_for_stickerSets_response'});
      final result = await _stickerSetsCompleter!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger.logError('getInstalledStickerSets timed out');
          return <StickerSet>[];
        },
      );
      _logger.logRequest({
        '@type': 'DEBUG_got_stickerSets',
        'count': result.length,
      });
      return result;
    } catch (e) {
      _logger.logError('Failed to get installed sticker sets', error: e);
      return [];
    }
  }

  // Track pending sticker set requests by ID to avoid race conditions
  final Map<int, Completer<StickerSet>> _pendingStickerSetRequests = {};

  @override
  Future<StickerSet?> getStickerSet(int setId) async {
    // Return cached if available
    if (_stickerSetsCache.containsKey(setId)) {
      return _stickerSetsCache[setId];
    }

    // If there's already a pending request for this set, reuse it
    if (_pendingStickerSetRequests.containsKey(setId)) {
      return _pendingStickerSetRequests[setId]!.future;
    }

    final completer = Completer<StickerSet>();
    _pendingStickerSetRequests[setId] = completer;
    _stickerSetCompleter = completer;

    await _sendRequest({'@type': 'getStickerSet', 'set_id': setId});

    // Wait for response with timeout
    try {
      final result = await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('getStickerSet timeout'),
      );
      _stickerSetsCache[setId] = result;
      return result;
    } catch (e) {
      _logger.logError('Failed to get sticker set $setId', error: e);
      return null;
    } finally {
      _pendingStickerSetRequests.remove(setId);
    }
  }

  @override
  Future<List<Sticker>> getRecentStickers() async {
    // If there's already a pending request, reuse it
    if (_recentStickersCompleter != null &&
        !_recentStickersCompleter!.isCompleted) {
      return _recentStickersCompleter!.future;
    }

    _recentStickersCompleter = Completer<List<Sticker>>();

    await _sendRequest({'@type': 'getRecentStickers', 'is_attached': false});

    // Wait for response with timeout
    try {
      final result = await _recentStickersCompleter!.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => <Sticker>[],
      );
      return result;
    } catch (e) {
      _logger.logError('Failed to get recent stickers', error: e);
      return [];
    }
  }

  @override
  Future<void> sendSticker(int chatId, Sticker sticker) async {
    try {
      await _sendRequest({
        '@type': 'sendMessage',
        'chat_id': chatId,
        'input_message_content': {
          '@type': 'inputMessageSticker',
          'sticker': {'@type': 'inputFileId', 'id': sticker.fileId},
          'width': sticker.width,
          'height': sticker.height,
          'emoji': sticker.emoji,
        },
      });
    } catch (e) {
      _logger.logError('Failed to send sticker to chat $chatId', error: e);
    }
  }

  void _handleStickerSetsResponse(Map<String, dynamic> update) {
    try {
      final setInfos = update['sets'] as List<dynamic>? ?? [];
      _installedStickerSets.clear();

      _logger.logRequest({
        '@type': 'DEBUG_parsing_sticker_sets',
        'raw_count': setInfos.length,
        'first_type': setInfos.isNotEmpty
            ? setInfos.first.runtimeType.toString()
            : 'empty',
      });

      for (final setInfo in setInfos) {
        try {
          // Cast to Map more safely
          final Map<String, dynamic> setMap = Map<String, dynamic>.from(
            setInfo as Map,
          );
          final stickerSet = StickerSet.fromInfoJson(setMap);
          _installedStickerSets.add(stickerSet);
        } catch (e) {
          _logger.logError('Error parsing sticker set', error: e);
        }
      }

      _logger.logRequest({
        '@type': 'sticker_sets_loaded',
        'count': _installedStickerSets.length,
      });

      if (_stickerSetsCompleter != null &&
          !_stickerSetsCompleter!.isCompleted) {
        _stickerSetsCompleter!.complete(_installedStickerSets);
      }
    } catch (e) {
      _logger.logError('Error handling sticker sets response', error: e);
      if (_stickerSetsCompleter != null &&
          !_stickerSetsCompleter!.isCompleted) {
        _stickerSetsCompleter!.complete([]);
      }
    }
  }

  void _handleStickerSetResponse(Map<String, dynamic> update) {
    try {
      final stickerSet = StickerSet.fromJson(update);

      _logger.logRequest({
        '@type': 'sticker_set_loaded',
        'set_id': stickerSet.id,
        'sticker_count': stickerSet.stickers.length,
      });

      if (_stickerSetCompleter != null && !_stickerSetCompleter!.isCompleted) {
        _stickerSetCompleter!.complete(stickerSet);
      }
    } catch (e) {
      _logger.logError('Error handling sticker set response', error: e);
      if (_stickerSetCompleter != null && !_stickerSetCompleter!.isCompleted) {
        _stickerSetCompleter!.completeError(e);
      }
    }
  }

  void _handleRecentStickersResponse(Map<String, dynamic> update) {
    try {
      final stickersJson = update['stickers'] as List<dynamic>? ?? [];
      final List<Sticker> stickers = [];

      for (final stickerData in stickersJson) {
        try {
          final Map<String, dynamic> stickerMap = Map<String, dynamic>.from(
            stickerData as Map,
          );
          stickers.add(Sticker.fromJson(stickerMap));
        } catch (e) {
          _logger.logError('Error parsing recent sticker', error: e);
        }
      }

      _logger.logRequest({
        '@type': 'recent_stickers_loaded',
        'count': stickers.length,
      });

      if (_recentStickersCompleter != null &&
          !_recentStickersCompleter!.isCompleted) {
        _recentStickersCompleter!.complete(stickers);
      }
    } catch (e) {
      _logger.logError('Error handling recent stickers response', error: e);
      if (_recentStickersCompleter != null &&
          !_recentStickersCompleter!.isCompleted) {
        _recentStickersCompleter!.complete([]);
      }
    }
  }

  @override
  void dispose() {
    _receiveTimer?.cancel();
    _updateController.close();
    _authController.close();
    _fileDownloadController.close();
    _chatEventController.close();
    _messageEventController.close();
    _client?.destroy();
  }
}
