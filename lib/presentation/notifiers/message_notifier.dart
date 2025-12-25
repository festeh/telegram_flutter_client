import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/entities/chat.dart';
import '../../domain/events/message_events.dart';
import '../state/message_state.dart';
import '../../core/logging/app_logger.dart';
import '../providers/telegram_client_provider.dart';

const _lastSelectedChatKey = 'last_selected_chat_id';

class MessageNotifier extends AsyncNotifier<MessageState> {
  late final TelegramClientRepository _client;
  StreamSubscription<MessageEvent>? _eventSubscription;
  final AppLogger _logger = AppLogger.instance;

  @override
  Future<MessageState> build() async {
    // Use the shared client instance from provider
    _client = ref.read(telegramClientProvider);

    // Start listening to message events
    _listenToMessageEvents();

    // Load last selected chat from storage
    final prefs = await SharedPreferences.getInstance();
    final lastChatId = prefs.getInt(_lastSelectedChatKey);

    if (lastChatId != null) {
      // Return state with last selected chat and trigger message loading
      final initialState = MessageState.initial().selectChat(lastChatId);
      // Load messages for the restored chat after a short delay to let chats load first
      Future.delayed(const Duration(milliseconds: 500), () {
        loadMessages(lastChatId);
      });
      return initialState;
    }

    // Initialize with empty state
    return MessageState.initial();
  }

  void _listenToMessageEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = _client.messageEvents.listen(
      _handleMessageEvent,
      onError: (error) {
        _setError('Error receiving message events: $error');
      },
    );
  }

  void _handleMessageEvent(MessageEvent event) {
    switch (event) {
      case MessageAddedEvent(:final chatId, :final message):
        _handleNewMessage(chatId, message);
      case MessageEditedEvent(:final chatId, :final message):
        _handleMessageEdited(chatId, message);
      case MessagesDeletedEvent(:final chatId, :final messageIds):
        _handleMessagesDeleted(chatId, messageIds);
      case MessageContentChangedEvent(:final chatId, :final messageId, :final newContent):
        _handleMessageContentChanged(chatId, messageId, newContent);
      case MessageSendSucceededEvent(:final chatId, :final message):
        _handleMessageSendSucceeded(chatId, message);
      case MessageSendFailedEvent(:final errorMessage):
        _handleMessageSendFailed(errorMessage);
      case MessagesBatchReceivedEvent(:final chatId, :final messages):
        _handleMessagesBatch(chatId, messages);
      case MessagePhotoUpdatedEvent(:final chatId, :final messageId, :final photoPath):
        _handleMessagePhotoUpdated(chatId, messageId, photoPath);
      case MessageStickerUpdatedEvent(:final chatId, :final messageId, :final stickerPath):
        _handleMessageStickerUpdated(chatId, messageId, stickerPath);
      case MessageReactionsUpdatedEvent(:final chatId, :final messageId, :final reactions):
        _handleMessageReactionsUpdated(chatId, messageId, reactions);
    }
  }

  void _handleMessagePhotoUpdated(int chatId, int messageId, String photoPath) {
    _logger.debug('Message photo updated in chat $chatId: $messageId');
    final currentState = state.value;
    if (currentState == null) return;

    final messages = currentState.messagesByChat[chatId];
    if (messages == null) return;

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final updatedMessage = messages[index].copyWith(photoPath: photoPath);
    state = AsyncData(currentState.updateMessage(chatId, updatedMessage));
  }

  void _handleMessageStickerUpdated(int chatId, int messageId, String stickerPath) {
    _logger.debug('Message sticker updated in chat $chatId: $messageId');
    final currentState = state.value;
    if (currentState == null) return;

    final messages = currentState.messagesByChat[chatId];
    if (messages == null) return;

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final updatedMessage = messages[index].copyWith(stickerPath: stickerPath);
    state = AsyncData(currentState.updateMessage(chatId, updatedMessage));
  }

  void _handleMessageReactionsUpdated(int chatId, int messageId, List<MessageReaction> reactions) {
    _logger.debug('Message reactions updated in chat $chatId: $messageId');
    final currentState = state.value;
    if (currentState == null) return;

    final messages = currentState.messagesByChat[chatId];
    if (messages == null) return;

    final index = messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final updatedMessage = messages[index].copyWith(reactions: reactions.isEmpty ? null : reactions);
    state = AsyncData(currentState.updateMessage(chatId, updatedMessage));
  }

  void _handleNewMessage(int chatId, Message message) {
    _logger.debug('New message received for chat $chatId');
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.addMessage(chatId, message));
    }
  }

  void _handleMessageEdited(int chatId, Message message) {
    _logger.debug('Message edited in chat $chatId: ${message.id}');
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.updateMessage(chatId, message));
    }
  }

  void _handleMessagesDeleted(int chatId, List<int> messageIds) {
    _logger.debug('Messages deleted in chat $chatId: $messageIds');
    final currentState = state.value;
    if (currentState != null) {
      var newState = currentState;
      for (final messageId in messageIds) {
        newState = newState.removeMessage(chatId, messageId);
      }
      state = AsyncData(newState);
    }
  }

  void _handleMessageContentChanged(int chatId, int messageId, Map<String, dynamic> newContent) {
    _logger.debug('Message content changed in chat $chatId: $messageId');
    // Content update handling - placeholder until Message supports content updates
    final currentState = state.value;
    if (currentState != null && currentState.messagesByChat.containsKey(chatId)) {
      final messages = currentState.messagesByChat[chatId]!;
      final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
      if (messageIndex != -1) {
        // Placeholder - message content update would go here
        state = AsyncData(currentState);
      }
    }
  }

  void _handleMessageSendSucceeded(int chatId, Message message) {
    _logger.debug('Message send succeeded for chat $chatId: ${message.id}');
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.updateMessage(chatId, message).setSending(false));
    }
  }

  void _handleMessageSendFailed(String errorMessage) {
    _logger.error('Message send failed: $errorMessage');
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(
        currentState.setSending(false).setError('Failed to send message: $errorMessage'),
      );
    }
  }

  void _handleMessagesBatch(int chatId, List<Message> messages) {
    _logger.debug('Received batch of ${messages.length} messages for chat $chatId');
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(
        currentState.addMessages(chatId, messages).setLoading(false).setLoadingMore(false),
      );
    }
  }

  // Public methods for UI actions

  Future<void> loadMessages(int chatId, {bool forceRefresh = false}) async {
    try {
      final currentState = state.value ?? MessageState.initial();

      // Set loading state
      state = AsyncData(currentState.selectChat(chatId).setLoading(true));

      // Load messages from client
      final messages = await _client.loadMessages(chatId);

      _logger.debug('Loaded ${messages.length} messages for chat $chatId');

      // Trigger media downloads for messages that need them
      _downloadMessageMedia(messages);

      // Update state with loaded messages
      final newState = currentState
          .selectChat(chatId)
          .addMessages(chatId, messages)
          .setLoading(false);

      state = AsyncData(newState);
    } catch (e) {
      _logger.error('Failed to load messages for chat $chatId', error: e);
      _setError('Failed to load messages: $e');
    }
  }

  void _downloadMessageMedia(List<Message> messages) {
    for (final message in messages) {
      // Download photos
      if (message.photoFileId != null &&
          (message.photoPath == null || message.photoPath!.isEmpty)) {
        _client.downloadFile(message.photoFileId!);
      }
      // Download stickers
      if (message.stickerFileId != null &&
          (message.stickerPath == null || message.stickerPath!.isEmpty)) {
        _client.downloadFile(message.stickerFileId!);
      }
    }
  }

  Future<void> loadMoreMessages(int chatId) async {
    try {
      final currentState = state.value;
      if (currentState == null || currentState.isLoadingMore) return;

      final existingMessages = currentState.messagesByChat[chatId] ?? [];
      if (existingMessages.isEmpty) return;

      // Set loading more state
      state = AsyncData(currentState.setLoadingMore(true));

      // Get oldest message ID for pagination
      final oldestMessageId = existingMessages.last.id;

      // Load more messages from client
      final messages = await _client.loadMessages(chatId, fromMessageId: oldestMessageId);

      _logger.debug('Loaded ${messages.length} more messages for chat $chatId');

      // Update state with additional messages
      final newState = currentState
          .addMessages(chatId, messages)
          .setLoadingMore(false);

      state = AsyncData(newState);
    } catch (e) {
      _logger.error('Failed to load more messages for chat $chatId', error: e);
      _setError('Failed to load more messages: $e');
    }
  }

  Future<void> sendMessage(int chatId, String text) async {
    if (text.trim().isEmpty) return;

    try {
      final currentState = state.value ?? MessageState.initial();
      
      // Set sending state
      state = AsyncData(currentState.setSending(true));

      // Send message via client
      await _client.sendMessage(chatId, text);

      _logger.debug('Message sent to chat $chatId');

      // The actual message will be added via updateNewMessage event
      // Just clear the sending state
      final newState = currentState.setSending(false);
      state = AsyncData(newState);

    } catch (e) {
      _logger.error('Failed to send message to chat $chatId', error: e);
      _setError('Failed to send message: $e');
    }
  }

  Future<void> editMessage(int chatId, int messageId, String newText) async {
    try {
      await _client.editMessage(chatId, messageId, newText);
      _logger.debug('Message edited in chat $chatId: $messageId');
    } catch (e) {
      _logger.error('Failed to edit message $messageId in chat $chatId', error: e);
      _setError('Failed to edit message: $e');
    }
  }

  Future<void> deleteMessage(int chatId, int messageId) async {
    try {
      final success = await _client.deleteMessage(chatId, messageId);
      if (success) {
        _logger.debug('Message deleted in chat $chatId: $messageId');
      } else {
        _setError('Failed to delete message');
      }
    } catch (e) {
      _logger.error('Failed to delete message $messageId in chat $chatId', error: e);
      _setError('Failed to delete message: $e');
    }
  }

  Future<void> markAsRead(int chatId, int messageId) async {
    try {
      await _client.markAsRead(chatId, messageId);
      _logger.debug('Message marked as read in chat $chatId: $messageId');
    } catch (e) {
      _logger.error('Failed to mark message as read $messageId in chat $chatId', error: e);
    }
  }

  void selectChat(int chatId) async {
    final currentState = state.value ?? MessageState.initial();
    state = AsyncData(currentState.selectChat(chatId));

    // Persist the selected chat ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSelectedChatKey, chatId);
  }

  // State management helpers

  void _setError(String errorMessage) {
    final currentState = state.value ?? MessageState.initial();
    state = AsyncData(currentState.setError(errorMessage));
  }

  void clearError() {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.clearError());
    }
  }

  // Cleanup
  void dispose() {
    _eventSubscription?.cancel();
  }
}