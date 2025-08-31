import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/entities/chat.dart';
import '../state/chat_state.dart';
import '../../core/logging/app_logger.dart';
import '../providers/telegram_client_provider.dart';

class ChatNotifier extends AsyncNotifier<ChatState> {
  late final TelegramClientRepository _client;
  StreamSubscription<Map<String, dynamic>>? _updateSubscription;
  Timer? _refreshTimer;
  final AppLogger _logger = AppLogger.instance;

  @override
  Future<ChatState> build() async {
    // Use the shared client instance from provider
    _client = ref.read(telegramClientProvider);

    // Start listening to chat updates
    _listenToUpdates();

    // Load initial chats
    return await _loadChats();
  }

  void _listenToUpdates() {
    _updateSubscription?.cancel();
    _updateSubscription = _client.updates.listen(
      (update) {
        _handleUpdate(update);
      },
      onError: (error) {
        _setError('Error receiving updates: $error');
      },
    );
  }

  void _handleUpdate(Map<String, dynamic> update) {
    final updateType = update['@type'] as String;

    switch (updateType) {
      case 'updateNewChat':
        _handleNewChatUpdate(update);
        break;
      case 'updateNewMessage':
        _handleNewMessage(update);
        break;
      case 'updateChatTitle':
        _handleChatTitleUpdate(update);
        break;
      case 'updateChatPhoto':
        _handleChatPhotoUpdate(update);
        break;
      case 'updateChatLastMessage':
        _handleChatLastMessageUpdate(update);
        break;
      case 'updateChatOrder':
        _handleChatOrderUpdate(update);
        break;
      case 'updateChatReadInbox':
        _handleChatReadUpdate(update);
        break;
      default:
        // Ignore other update types for now
        break;
    }
  }

  void _handleNewChatUpdate(Map<String, dynamic> update) {
    try {
      final chatData = update['chat'] as Map<String, dynamic>?;
      if (chatData == null) return;

      final chat = Chat.fromJson(chatData);
      _logger.info('New chat received: ${chat.title} (ID: ${chat.id})');

      final currentState = state.valueOrNull;
      if (currentState != null) {
        final newState = currentState.addChat(chat);
        state = AsyncData(newState.sortByLastActivity());
        _logger.info('Chat added to state. Total chats: ${newState.chatCount}');
      }
    } catch (e) {
      _logger.error('Error handling updateNewChat', error: e);
    }
  }

  void _handleNewMessage(Map<String, dynamic> update) {
    try {
      final message = update['message'] as Map<String, dynamic>?;
      if (message == null) return;

      final chatId = message['chat_id'] as int?;
      if (chatId == null) return;

      // Update the chat with new last message
      _updateChatFromMessage(chatId, message);
    } catch (e) {
      // Log error but don't fail the entire update
      _logger.error('Error handling new message update', error: e);
    }
  }

  void _handleChatTitleUpdate(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final title = update['title'] as String?;

    if (chatId != null && title != null) {
      _updateChatProperty(chatId, (chat) => chat.copyWith(title: title));
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

      _updateChatProperty(
          chatId, (chat) => chat.copyWith(photoPath: photoPath));
    }
  }

  void _handleChatLastMessageUpdate(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final messageData = update['last_message'] as Map<String, dynamic>?;

    if (chatId != null && messageData != null) {
      _updateChatFromMessage(chatId, messageData);
    }
  }

  void _handleChatOrderUpdate(Map<String, dynamic> update) {
    // When chat order changes, we should re-sort the chat list
    final currentState = state.valueOrNull;
    if (currentState != null) {
      state = AsyncData(currentState.sortByLastActivity());
    }
  }

  void _handleChatReadUpdate(Map<String, dynamic> update) {
    final chatId = update['chat_id'] as int?;
    final unreadCount = update['unread_count'] as int?;

    if (chatId != null && unreadCount != null) {
      _updateChatProperty(
          chatId, (chat) => chat.copyWith(unreadCount: unreadCount));
    }
  }

  void _updateChatFromMessage(int chatId, Map<String, dynamic> messageData) {
    try {
      final message = Message.fromJson(messageData);
      final lastActivity = DateTime.fromMillisecondsSinceEpoch(
        (messageData['date'] as int) * 1000,
      );

      _updateChatProperty(
          chatId,
          (chat) => chat.copyWith(
                lastMessage: message,
                lastActivity: lastActivity,
              ));
    } catch (e) {
      _logger.error('Error updating chat from message', error: e);
    }
  }

  void _updateChatProperty(int chatId, Chat Function(Chat) updater) {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    final chatIndex = currentState.chats.indexWhere((c) => c.id == chatId);
    if (chatIndex == -1) return;

    final currentChat = currentState.chats[chatIndex];
    final updatedChat = updater(currentChat);

    final newState = currentState.updateChat(updatedChat);
    state = AsyncData(newState.sortByLastActivity());
  }

  Future<ChatState> _loadChats() async {
    try {
      _setLoading(true);

      // Load chats from the client
      final chats = await _client.loadChats(limit: 50);

      _logger.info(
          'Chat loading result: ${chats.length} chats loaded from client');

      // Return the chats (could be empty initially if updates haven't arrived yet)
      final chatState = ChatState.loaded(chats);

      // If no chats yet, the real ones will come via updateNewChat events
      if (chats.isEmpty) {
        _logger.info(
            'No cached chats yet, real chats will arrive via updateNewChat events');
        // For development: add test data if no real chats after a delay
        Future.delayed(const Duration(seconds: 2), () {
          final currentState = state.valueOrNull;
          if (currentState != null && currentState.chats.isEmpty) {
            _logger.info(
                'Still no real chats after 2 seconds, adding test data for development');
            final testChats = _createTestChats();
            final newState = ChatState.loaded(testChats);
            state = AsyncData(newState.sortByLastActivity());
          }
        });
      }

      _setLoading(false);
      return chatState.sortByLastActivity();
    } catch (e) {
      _logger.error('Failed to load chats', error: e);

      // On error, start with empty state, real chats will still come via updates
      _logger.info(
          'Starting with empty state, real chats will arrive via updates');
      final chatState = ChatState.loaded([]);
      _setLoading(false);
      return chatState.sortByLastActivity();
    }
  }

  List<Chat> _createTestChats() {
    final now = DateTime.now();
    return [
      Chat(
        id: 1,
        title: 'John Doe',
        type: ChatType.private,
        lastMessage: Message(
          id: 1,
          chatId: 1,
          senderId: 2,
          date: now.subtract(const Duration(minutes: 5)),
          content: 'Hey, how are you doing?',
          isOutgoing: false,
          type: MessageType.text,
        ),
        unreadCount: 2,
        lastActivity: now.subtract(const Duration(minutes: 5)),
      ),
      Chat(
        id: 2,
        title: 'Flutter Developers',
        type: ChatType.supergroup,
        lastMessage: Message(
          id: 2,
          chatId: 2,
          senderId: 3,
          date: now.subtract(const Duration(hours: 1)),
          content: 'Check out this new widget!',
          isOutgoing: false,
          type: MessageType.text,
        ),
        unreadCount: 5,
        lastActivity: now.subtract(const Duration(hours: 1)),
      ),
      Chat(
        id: 3,
        title: 'Sarah Wilson',
        type: ChatType.private,
        lastMessage: Message(
          id: 3,
          chatId: 3,
          senderId: 1,
          date: now.subtract(const Duration(hours: 3)),
          content: 'Thanks for the help!',
          isOutgoing: true,
          type: MessageType.text,
        ),
        unreadCount: 0,
        lastActivity: now.subtract(const Duration(hours: 3)),
      ),
      Chat(
        id: 4,
        title: 'Project Team',
        type: ChatType.basicGroup,
        lastMessage: Message(
          id: 4,
          chatId: 4,
          senderId: 4,
          date: now.subtract(const Duration(days: 1)),
          content: 'Meeting scheduled for tomorrow',
          isOutgoing: false,
          type: MessageType.text,
        ),
        unreadCount: 1,
        lastActivity: now.subtract(const Duration(days: 1)),
      ),
    ];
  }

  // Public methods for UI actions

  Future<void> refreshChats() async {
    final newState = await _loadChats();
    state = AsyncData(newState);
  }

  Future<void> loadMoreChats() async {
    final currentState = state.valueOrNull;
    if (currentState == null || currentState.isLoading) return;

    try {
      _setLoading(true);

      // Load more chats starting from the last chat
      final moreChats = await _client.loadChats(
        limit: 20,
        offsetChatId:
            currentState.chats.isNotEmpty ? currentState.chats.last.id : 0,
      );

      // Add new chats to existing list
      var newState = currentState;
      for (final chat in moreChats) {
        newState = newState.addChat(chat);
      }

      state = AsyncData(newState.sortByLastActivity().setLoading(false));
    } catch (e) {
      _setError('Failed to load more chats: $e');
    }
  }

  // State management helpers

  void _setLoading(bool isLoading) {
    final currentState = state.valueOrNull ?? ChatState.initial();
    state = AsyncData(currentState.setLoading(isLoading));
  }

  void _setError(String errorMessage) {
    final currentState = state.valueOrNull ?? ChatState.initial();
    state = AsyncData(currentState.setError(errorMessage));
  }

  void clearError() {
    final currentState = state.valueOrNull;
    if (currentState != null) {
      state = AsyncData(currentState.clearError());
    }
  }

  // Cleanup
  void dispose() {
    _updateSubscription?.cancel();
    _refreshTimer?.cancel();
  }
}
