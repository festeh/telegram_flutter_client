import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/entities/chat.dart';
import '../../domain/events/chat_events.dart';
import '../state/chat_state.dart';
import '../../core/logging/app_logger.dart';
import '../providers/telegram_client_provider.dart';
import '../../core/config/app_config.dart';

class ChatNotifier extends AsyncNotifier<ChatState> {
  late final TelegramClientRepository _client;
  StreamSubscription<ChatEvent>? _eventSubscription;
  final AppLogger _logger = AppLogger.instance;

  @override
  Future<ChatState> build() async {
    // Use the shared client instance from provider
    _client = ref.read(telegramClientProvider);

    // Start listening to chat events
    _listenToChatEvents();

    // Load initial chats
    return await _loadChats();
  }

  void _listenToChatEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = _client.chatEvents.listen(
      _handleChatEvent,
      onError: (error) {
        _setError('Error receiving chat events: $error');
      },
    );
  }

  void _handleChatEvent(ChatEvent event) {
    switch (event) {
      case ChatAddedEvent(:final chat):
        _handleChatAdded(chat);
      case ChatTitleUpdatedEvent(:final chatId, :final title):
        _updateChatProperty(chatId, (chat) => chat.copyWith(title: title));
      case ChatPhotoUpdatedEvent(:final chatId, :final photoPath):
        _updateChatProperty(chatId, (chat) => chat.copyWith(photoPath: photoPath));
      case ChatLastMessageUpdatedEvent(:final chatId, :final lastMessage, :final lastActivity):
        _updateChatProperty(
          chatId,
          (chat) => chat.copyWith(lastMessage: lastMessage, lastActivity: lastActivity),
        );
      case ChatUnreadCountUpdatedEvent(:final chatId, :final unreadCount):
        _updateChatProperty(chatId, (chat) => chat.copyWith(unreadCount: unreadCount));
      case ChatPositionChangedEvent(:final chatId, :final isInMainList):
        _updateChatProperty(chatId, (chat) => chat.copyWith(isInMainList: isInMainList));
      case ChatOrderChangedEvent():
        _resortChats();
    }
  }

  void _handleChatAdded(Chat chat) {
    _logger.debug('New chat received: ${chat.title} (ID: ${chat.id})');

    // Trigger photo download if needed
    _downloadChatPhoto(chat);

    final currentState = state.valueOrNull;
    if (currentState != null) {
      final newState = currentState.addChat(chat);
      state = AsyncData(newState.sortByLastActivity());
      _logger.debug('Chat added to state. Total chats: ${newState.chatCount}');
    }
  }

  void _resortChats() {
    final currentState = state.valueOrNull;
    if (currentState != null) {
      state = AsyncData(currentState.sortByLastActivity());
    }
  }

  void _downloadChatPhotos(List<Chat> chats) {
    for (final chat in chats) {
      _downloadChatPhoto(chat);
    }
  }

  void _downloadChatPhoto(Chat chat) {
    if (chat.photoFileId != null &&
        (chat.photoPath == null || chat.photoPath!.isEmpty)) {
      _logger.debug('Requesting photo download for chat ${chat.title} (fileId: ${chat.photoFileId})');
      _client.downloadFile(chat.photoFileId!);
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
      final chats = await _client.loadChats(limit: AppConfig.chatPageSize);

      _logger.debug(
          'Chat loading result: ${chats.length} chats loaded from client');

      // Trigger photo downloads for chats that need them
      _downloadChatPhotos(chats);

      // Return the chats (could be empty initially if updates haven't arrived yet)
      // Real chats will arrive via updateNewChat events
      final chatState = ChatState.loaded(chats);

      _setLoading(false);
      return chatState.sortByLastActivity();
    } catch (e) {
      _logger.error('Failed to load chats', error: e);

      // On error, start with empty state, real chats will still come via updates
      _logger.debug(
          'Starting with empty state, real chats will arrive via updates');
      final chatState = ChatState.loaded([]);
      _setLoading(false);
      return chatState.sortByLastActivity();
    }
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
    _eventSubscription?.cancel();
  }
}
