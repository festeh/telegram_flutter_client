import '../../domain/entities/chat.dart';

class ChatState {
  final List<Chat> chats;
  final bool isLoading;
  final String? errorMessage;
  final bool isInitialized;
  final int _version; // Used to force rebuilds on status updates

  const ChatState({
    this.chats = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isInitialized = false,
    int version = 0,
  }) : _version = version;

  // Factory constructors for common states
  factory ChatState.initial() => const ChatState(
        isLoading: true,
        isInitialized: false,
      );

  factory ChatState.error(String message) => ChatState(
        errorMessage: message,
        isLoading: false,
        isInitialized: false,
      );

  factory ChatState.loaded(List<Chat> chats) => ChatState(
        chats: chats,
        isLoading: false,
        isInitialized: true,
      );

  // Copy with method for immutable updates
  ChatState copyWith({
    List<Chat>? chats,
    bool? isLoading,
    String? errorMessage,
    bool? isInitialized,
    int? version,
  }) {
    return ChatState(
      chats: chats ?? this.chats,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      isInitialized: isInitialized ?? this.isInitialized,
      version: version ?? _version,
    );
  }

  // Increment version to force UI rebuild
  ChatState bumpVersion() => copyWith(version: _version + 1);

  // Helper methods
  ChatState setLoading(bool loading) => copyWith(isLoading: loading);
  ChatState clearError() => copyWith(errorMessage: null);
  ChatState setError(String error) =>
      copyWith(errorMessage: error, isLoading: false);

  // Computed properties
  bool get hasError => errorMessage != null;
  bool get isEmpty => chats.isEmpty;
  int get chatCount => chats.length;

  // Add/update/remove chat methods
  ChatState addChat(Chat chat) {
    if (chats.any((c) => c.id == chat.id)) {
      return updateChat(chat);
    }
    final newChats = List<Chat>.from(chats)..add(chat);
    return copyWith(chats: newChats);
  }

  ChatState updateChat(Chat updatedChat) {
    final newChats = chats.map((chat) {
      return chat.id == updatedChat.id ? updatedChat : chat;
    }).toList();
    return copyWith(chats: newChats);
  }

  ChatState removeChat(int chatId) {
    final newChats = chats.where((chat) => chat.id != chatId).toList();
    return copyWith(chats: newChats);
  }

  // Sort chats by last activity (most recent first)
  ChatState sortByLastActivity() {
    final sortedChats = List<Chat>.from(chats)
      ..sort((a, b) {
        final aTime = a.lastActivity ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.lastActivity ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    return copyWith(chats: sortedChats);
  }

  @override
  String toString() {
    return 'ChatState(chats: ${chats.length}, isLoading: $isLoading, hasError: $hasError, isInitialized: $isInitialized)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatState &&
        other.chats.length == chats.length &&
        other.isLoading == isLoading &&
        other.errorMessage == errorMessage &&
        other.isInitialized == isInitialized &&
        other._version == _version;
  }

  @override
  int get hashCode {
    return Object.hash(
      chats.length,
      isLoading,
      errorMessage,
      isInitialized,
      _version,
    );
  }
}
