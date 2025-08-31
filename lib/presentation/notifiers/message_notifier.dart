import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/entities/chat.dart';
import '../state/message_state.dart';
import '../../core/logging/app_logger.dart';
import '../providers/telegram_client_provider.dart';

class MessageNotifier extends AsyncNotifier<MessageState> {
  late final TelegramClientRepository _client;
  StreamSubscription<Map<String, dynamic>>? _updateSubscription;
  final AppLogger _logger = AppLogger.instance;

  @override
  Future<MessageState> build() async {
    // Use the shared client instance from provider
    _client = ref.read(telegramClientProvider);

    // Start listening to message updates
    _listenToUpdates();

    // Initialize with empty state
    return MessageState.initial();
  }

  void _listenToUpdates() {
    _updateSubscription?.cancel();
    _updateSubscription = _client.updates.listen(
      (update) {
        _handleUpdate(update);
      },
      onError: (error) {
        _setError('Error receiving message updates: $error');
      },
    );
  }

  void _handleUpdate(Map<String, dynamic> update) {
    final updateType = update['@type'] as String;

    switch (updateType) {
      case 'updateNewMessage':
        _handleNewMessage(update);
        break;
      case 'updateMessageEdited':
        _handleMessageEdited(update);
        break;
      case 'updateDeleteMessages':
        _handleDeleteMessages(update);
        break;
      case 'updateMessageContent':
        _handleMessageContentChanged(update);
        break;
      case 'updateMessageSendSucceeded':
        _handleMessageSendSucceeded(update);
        break;
      case 'updateMessageSendFailed':
        _handleMessageSendFailed(update);
        break;
      case 'messages':
        // Handle batch messages response from getChatHistory
        _handleMessagesResponse(update);
        break;
      default:
        // Ignore other update types
        break;
    }
  }

  void _handleNewMessage(Map<String, dynamic> update) {
    try {
      final messageData = update['message'] as Map<String, dynamic>?;
      if (messageData == null) return;

      final message = Message.fromJson(messageData);
      final chatId = message.chatId;

      _logger.info('New message received for chat $chatId: ${message.content}');

      final currentState = state.valueOrNull;
      if (currentState != null) {
        final newState = currentState.addMessage(chatId, message);
        state = AsyncData(newState);
      }
    } catch (e) {
      _logger.error('Error handling new message', error: e);
    }
  }

  void _handleMessageEdited(Map<String, dynamic> update) {
    try {
      final messageData = update['message'] as Map<String, dynamic>?;
      if (messageData == null) return;

      final message = Message.fromJson(messageData);
      final chatId = message.chatId;

      _logger.info('Message edited in chat $chatId: ${message.id}');

      final currentState = state.valueOrNull;
      if (currentState != null) {
        final newState = currentState.updateMessage(chatId, message);
        state = AsyncData(newState);
      }
    } catch (e) {
      _logger.error('Error handling message edit', error: e);
    }
  }

  void _handleDeleteMessages(Map<String, dynamic> update) {
    try {
      final chatId = update['chat_id'] as int?;
      final messageIds = update['message_ids'] as List?;

      if (chatId == null || messageIds == null) return;

      _logger.info('Messages deleted in chat $chatId: $messageIds');

      final currentState = state.valueOrNull;
      if (currentState != null) {
        var newState = currentState;
        for (final messageId in messageIds) {
          if (messageId is int) {
            newState = newState.removeMessage(chatId, messageId);
          }
        }
        state = AsyncData(newState);
      }
    } catch (e) {
      _logger.error('Error handling message deletion', error: e);
    }
  }

  void _handleMessageContentChanged(Map<String, dynamic> update) {
    try {
      final chatId = update['chat_id'] as int?;
      final messageId = update['message_id'] as int?;
      final newContent = update['new_content'] as Map<String, dynamic>?;

      if (chatId == null || messageId == null || newContent == null) return;

      _logger.info('Message content changed in chat $chatId: $messageId');

      final currentState = state.valueOrNull;
      if (currentState != null && currentState.messagesByChat.containsKey(chatId)) {
        final messages = currentState.messagesByChat[chatId]!;
        final messageIndex = messages.indexWhere((msg) => msg.id == messageId);
        
        if (messageIndex != -1) {
          // Create updated message with new content
          final oldMessage = messages[messageIndex];
          // Note: We'd need to extend Message class to handle content updates properly
          final updatedMessage = oldMessage; // Placeholder for now
          
          final newState = currentState.updateMessage(chatId, updatedMessage);
          state = AsyncData(newState);
        }
      }
    } catch (e) {
      _logger.error('Error handling message content change', error: e);
    }
  }

  void _handleMessageSendSucceeded(Map<String, dynamic> update) {
    try {
      final messageData = update['message'] as Map<String, dynamic>?;
      if (messageData == null) return;

      final message = Message.fromJson(messageData);
      final chatId = message.chatId;

      _logger.info('Message send succeeded for chat $chatId: ${message.id}');

      final currentState = state.valueOrNull;
      if (currentState != null) {
        final newState = currentState.updateMessage(chatId, message).setSending(false);
        state = AsyncData(newState);
      }
    } catch (e) {
      _logger.error('Error handling message send success', error: e);
    }
  }

  void _handleMessageSendFailed(Map<String, dynamic> update) {
    try {
      final error = update['error'] as Map<String, dynamic>?;

      _logger.error('Message send failed', error: error);

      final currentState = state.valueOrNull;
      if (currentState != null) {
        final newState = currentState
            .setSending(false)
            .setError('Failed to send message: ${error?['message'] ?? 'Unknown error'}');
        state = AsyncData(newState);
      }
    } catch (e) {
      _logger.error('Error handling message send failure', error: e);
    }
  }

  void _handleMessagesResponse(Map<String, dynamic> update) {
    try {
      final messages = update['messages'] as List?;
      if (messages == null) return;

      _logger.info('Received batch of ${messages.length} messages');

      final currentState = state.valueOrNull;
      if (currentState != null && currentState.selectedChatId != null) {
        final chatId = currentState.selectedChatId!;
        final messageObjects = messages
            .map((msgData) => Message.fromJson(msgData as Map<String, dynamic>))
            .toList();

        final newState = currentState
            .addMessages(chatId, messageObjects)
            .setLoading(false)
            .setLoadingMore(false);
        state = AsyncData(newState);
      }
    } catch (e) {
      _logger.error('Error handling messages response', error: e);
    }
  }

  // Public methods for UI actions

  Future<void> loadMessages(int chatId, {bool forceRefresh = false}) async {
    try {
      final currentState = state.valueOrNull ?? MessageState.initial();
      
      // Set loading state
      state = AsyncData(currentState.selectChat(chatId).setLoading(true));

      // Load messages from client
      final messages = await _client.loadMessages(chatId);

      _logger.info('Loaded ${messages.length} messages for chat $chatId');

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

  Future<void> loadMoreMessages(int chatId) async {
    try {
      final currentState = state.valueOrNull;
      if (currentState == null || currentState.isLoadingMore) return;

      final existingMessages = currentState.messagesByChat[chatId] ?? [];
      if (existingMessages.isEmpty) return;

      // Set loading more state
      state = AsyncData(currentState.setLoadingMore(true));

      // Get oldest message ID for pagination
      final oldestMessageId = existingMessages.last.id;

      // Load more messages from client
      final messages = await _client.loadMessages(chatId, fromMessageId: oldestMessageId);

      _logger.info('Loaded ${messages.length} more messages for chat $chatId');

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
      final currentState = state.valueOrNull ?? MessageState.initial();
      
      // Set sending state
      state = AsyncData(currentState.setSending(true));

      // Send message via client
      await _client.sendMessage(chatId, text);

      _logger.info('Message sent to chat $chatId: $text');

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
      _logger.info('Message edited in chat $chatId: $messageId');
    } catch (e) {
      _logger.error('Failed to edit message $messageId in chat $chatId', error: e);
      _setError('Failed to edit message: $e');
    }
  }

  Future<void> deleteMessage(int chatId, int messageId) async {
    try {
      final success = await _client.deleteMessage(chatId, messageId);
      if (success) {
        _logger.info('Message deleted in chat $chatId: $messageId');
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
      _logger.info('Message marked as read in chat $chatId: $messageId');
    } catch (e) {
      _logger.error('Failed to mark message as read $messageId in chat $chatId', error: e);
    }
  }

  void selectChat(int chatId) {
    final currentState = state.valueOrNull ?? MessageState.initial();
    state = AsyncData(currentState.selectChat(chatId));
  }

  // State management helpers

  void _setError(String errorMessage) {
    final currentState = state.valueOrNull ?? MessageState.initial();
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
  }
}