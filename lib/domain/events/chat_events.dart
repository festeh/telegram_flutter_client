import '../entities/chat.dart';

/// Sealed class hierarchy for typed chat events.
/// These events are emitted by the data layer and consumed by the presentation layer.
sealed class ChatEvent {}

/// Emitted when a new chat is received from TDLib.
class ChatAddedEvent extends ChatEvent {
  final Chat chat;
  ChatAddedEvent(this.chat);
}

/// Emitted when a chat's title is updated.
class ChatTitleUpdatedEvent extends ChatEvent {
  final int chatId;
  final String title;
  ChatTitleUpdatedEvent(this.chatId, this.title);
}

/// Emitted when a chat's photo path is updated (after download completes).
class ChatPhotoUpdatedEvent extends ChatEvent {
  final int chatId;
  final String? photoPath;
  ChatPhotoUpdatedEvent(this.chatId, this.photoPath);
}

/// Emitted when a chat's last message is updated.
class ChatLastMessageUpdatedEvent extends ChatEvent {
  final int chatId;
  final Message lastMessage;
  final DateTime lastActivity;
  ChatLastMessageUpdatedEvent(this.chatId, this.lastMessage, this.lastActivity);
}

/// Emitted when unread count changes.
class ChatUnreadCountUpdatedEvent extends ChatEvent {
  final int chatId;
  final int unreadCount;
  ChatUnreadCountUpdatedEvent(this.chatId, this.unreadCount);
}

/// Emitted when chat position in list changes.
class ChatPositionChangedEvent extends ChatEvent {
  final int chatId;
  final bool isInMainList;
  ChatPositionChangedEvent(this.chatId, this.isInMainList);
}

/// Emitted when chat order changes and list should be re-sorted.
class ChatOrderChangedEvent extends ChatEvent {}
