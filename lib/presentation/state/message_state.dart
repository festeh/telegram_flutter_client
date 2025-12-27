import '../../domain/entities/chat.dart';

class MessageState {
  final Map<int, List<Message>> messagesByChat;
  final Set<int>
  initializedChatIds; // Tracks which chats have completed initial load
  final int? selectedChatId;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSending;
  final String? errorMessage;
  final bool isInitialized;
  // Reply tracking
  final Message? replyingToMessage;
  // Mark-as-read tracking per chat (chatId -> last marked messageId)
  final Map<int, int> lastMarkedMessageIds;

  const MessageState({
    this.messagesByChat = const {},
    this.initializedChatIds = const {},
    this.selectedChatId,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSending = false,
    this.errorMessage,
    this.isInitialized = false,
    this.replyingToMessage,
    this.lastMarkedMessageIds = const {},
  });

  // Factory constructors for common states
  factory MessageState.initial() =>
      const MessageState(isLoading: false, isInitialized: false);

  factory MessageState.error(String message) => MessageState(
    errorMessage: message,
    isLoading: false,
    isInitialized: false,
  );

  factory MessageState.loaded(Map<int, List<Message>> messages) => MessageState(
    messagesByChat: messages,
    isLoading: false,
    isInitialized: true,
  );

  // Copy with method for immutable updates
  // Use clearReplyingTo flag to explicitly clear replyingToMessage
  MessageState copyWith({
    Map<int, List<Message>>? messagesByChat,
    Set<int>? initializedChatIds,
    int? selectedChatId,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSending,
    String? errorMessage,
    bool? isInitialized,
    Message? replyingToMessage,
    bool clearReplyingTo = false,
    Map<int, int>? lastMarkedMessageIds,
  }) {
    return MessageState(
      messagesByChat: messagesByChat ?? this.messagesByChat,
      initializedChatIds: initializedChatIds ?? this.initializedChatIds,
      selectedChatId: selectedChatId ?? this.selectedChatId,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
      isInitialized: isInitialized ?? this.isInitialized,
      replyingToMessage: clearReplyingTo
          ? null
          : (replyingToMessage ?? this.replyingToMessage),
      lastMarkedMessageIds: lastMarkedMessageIds ?? this.lastMarkedMessageIds,
    );
  }

  // Mark a chat as initialized (completed initial load)
  MessageState markChatInitialized(int chatId) {
    final newSet = Set<int>.from(initializedChatIds)..add(chatId);
    return copyWith(initializedChatIds: newSet);
  }

  // Check if a chat has been initialized
  bool isChatInitialized(int chatId) => initializedChatIds.contains(chatId);

  // Get last marked message ID for a chat
  int? getLastMarkedMessageId(int chatId) => lastMarkedMessageIds[chatId];

  // Set last marked message ID for a chat
  MessageState setLastMarkedMessageId(int chatId, int messageId) {
    final newMap = Map<int, int>.from(lastMarkedMessageIds);
    newMap[chatId] = messageId;
    return copyWith(lastMarkedMessageIds: newMap);
  }

  // Helper methods
  MessageState setLoading(bool loading) => copyWith(isLoading: loading);
  MessageState setLoadingMore(bool loadingMore) =>
      copyWith(isLoadingMore: loadingMore);
  MessageState setSending(bool sending) => copyWith(isSending: sending);
  MessageState clearError() => copyWith(errorMessage: null);
  MessageState setError(String error) =>
      copyWith(errorMessage: error, isLoading: false);
  MessageState selectChat(int chatId) => copyWith(selectedChatId: chatId);
  MessageState setReplyingTo(Message message) =>
      copyWith(replyingToMessage: message);
  MessageState clearReplyingTo() => copyWith(clearReplyingTo: true);

  // Computed properties
  bool get hasError => errorMessage != null;
  bool get isEmpty => messagesByChat.isEmpty;
  int get totalMessageCount =>
      messagesByChat.values.fold(0, (sum, list) => sum + list.length);

  List<Message> get selectedChatMessages {
    if (selectedChatId == null) return [];
    return messagesByChat[selectedChatId!] ?? [];
  }

  bool get hasSelectedChat => selectedChatId != null;
  bool get selectedChatHasMessages => selectedChatMessages.isNotEmpty;

  // Message management methods
  MessageState addMessage(int chatId, Message message) {
    final newMessages = Map<int, List<Message>>.from(messagesByChat);
    if (!newMessages.containsKey(chatId)) {
      newMessages[chatId] = [];
    }

    // Check if message already exists to avoid duplicates
    final existingIndex = newMessages[chatId]!.indexWhere(
      (msg) => msg.id == message.id,
    );
    if (existingIndex != -1) {
      newMessages[chatId]![existingIndex] = message;
    } else {
      newMessages[chatId]!.insert(0, message);
    }

    return copyWith(messagesByChat: newMessages);
  }

  MessageState addMessages(int chatId, List<Message> messages) {
    final newMessages = Map<int, List<Message>>.from(messagesByChat);

    // Always ensure chat exists in map (to distinguish "never loaded" from "loaded but empty")
    if (!newMessages.containsKey(chatId)) {
      newMessages[chatId] = [];
    }

    if (messages.isEmpty) {
      return copyWith(messagesByChat: newMessages);
    }

    final existingList = newMessages[chatId]!;

    // Build a set of existing message IDs for O(1) lookup
    final existingIds = existingList.map((m) => m.id).toSet();

    // Filter out duplicates and add new messages
    final newMessagesToAdd = messages
        .where((m) => !existingIds.contains(m.id))
        .toList();

    if (newMessagesToAdd.isEmpty) return this;

    // Combine and sort once - O(n log n) instead of O(n²)
    final combined = [...existingList, ...newMessagesToAdd];
    combined.sort((a, b) => b.date.compareTo(a.date)); // Newest first

    newMessages[chatId] = combined;
    return copyWith(messagesByChat: newMessages);
  }

  MessageState updateMessage(int chatId, Message updatedMessage) {
    final newMessages = Map<int, List<Message>>.from(messagesByChat);
    if (newMessages.containsKey(chatId)) {
      final messageList = List<Message>.from(newMessages[chatId]!);
      final index = messageList.indexWhere(
        (msg) => msg.id == updatedMessage.id,
      );
      if (index != -1) {
        messageList[index] = updatedMessage;
        newMessages[chatId] = messageList;
      }
    }
    return copyWith(messagesByChat: newMessages);
  }

  MessageState removeMessage(int chatId, int messageId) {
    final newMessages = Map<int, List<Message>>.from(messagesByChat);
    if (newMessages.containsKey(chatId)) {
      newMessages[chatId] = newMessages[chatId]!
          .where((message) => message.id != messageId)
          .toList();
    }
    return copyWith(messagesByChat: newMessages);
  }

  MessageState clearChatMessages(int chatId) {
    final newMessages = Map<int, List<Message>>.from(messagesByChat);
    newMessages[chatId] = [];
    return copyWith(messagesByChat: newMessages);
  }

  @override
  String toString() {
    return 'MessageState(totalMessages: $totalMessageCount, selectedChat: $selectedChatId, isLoading: $isLoading, isSending: $isSending, hasError: $hasError)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MessageState) return false;

    // Compare primitive fields first (fast path)
    if (other.selectedChatId != selectedChatId ||
        other.isLoading != isLoading ||
        other.isLoadingMore != isLoadingMore ||
        other.isSending != isSending ||
        other.errorMessage != errorMessage ||
        other.isInitialized != isInitialized ||
        other.replyingToMessage?.id != replyingToMessage?.id ||
        other.lastMarkedMessageIds.length != lastMarkedMessageIds.length) {
      return false;
    }

    // Compare initializedChatIds
    if (!identical(other.initializedChatIds, initializedChatIds)) {
      if (other.initializedChatIds.length != initializedChatIds.length) {
        return false;
      }
      if (!other.initializedChatIds.containsAll(initializedChatIds)) {
        return false;
      }
    }

    // Compare messagesByChat - reference equality first for performance
    if (identical(other.messagesByChat, messagesByChat)) return true;

    // Compare map structure
    if (other.messagesByChat.length != messagesByChat.length) return false;

    // Compare each chat's message list by reference
    // We always create new lists on updates, so reference inequality means content changed
    for (final chatId in messagesByChat.keys) {
      final otherMessages = other.messagesByChat[chatId];
      final thisMessages = messagesByChat[chatId];
      if (otherMessages == null) return false;
      // If list references are different, states are different
      if (!identical(otherMessages, thisMessages)) return false;
    }

    return true;
  }

  @override
  int get hashCode {
    // Include messagesByChat in hash via its length and selected chat message count
    final selectedMessages = selectedChatId != null
        ? messagesByChat[selectedChatId]?.length ?? 0
        : 0;
    return Object.hash(
      selectedChatId,
      isLoading,
      isLoadingMore,
      isSending,
      errorMessage,
      isInitialized,
      messagesByChat.length,
      selectedMessages,
      initializedChatIds.length,
      replyingToMessage?.id,
      lastMarkedMessageIds.length,
    );
  }
}
