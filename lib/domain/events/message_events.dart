import '../entities/chat.dart';

/// Sealed class hierarchy for typed message events.
/// These events are emitted by the data layer and consumed by the presentation layer.
sealed class MessageEvent {}

/// Emitted when a new message is received.
class MessageAddedEvent extends MessageEvent {
  final int chatId;
  final Message message;
  MessageAddedEvent(this.chatId, this.message);
}

/// Emitted when a message is edited.
class MessageEditedEvent extends MessageEvent {
  final int chatId;
  final Message message;
  MessageEditedEvent(this.chatId, this.message);
}

/// Emitted when messages are deleted.
class MessagesDeletedEvent extends MessageEvent {
  final int chatId;
  final List<int> messageIds;
  MessagesDeletedEvent(this.chatId, this.messageIds);
}

/// Emitted when a message's content changes.
class MessageContentChangedEvent extends MessageEvent {
  final int chatId;
  final int messageId;
  final Map<String, dynamic> newContent;
  MessageContentChangedEvent(this.chatId, this.messageId, this.newContent);
}

/// Emitted when a message send succeeds.
class MessageSendSucceededEvent extends MessageEvent {
  final int chatId;
  final Message message;
  MessageSendSucceededEvent(this.chatId, this.message);
}

/// Emitted when a message send fails.
class MessageSendFailedEvent extends MessageEvent {
  final String errorMessage;
  MessageSendFailedEvent(this.errorMessage);
}

/// Emitted when a batch of messages is received (e.g., from getChatHistory).
class MessagesBatchReceivedEvent extends MessageEvent {
  final int chatId;
  final List<Message> messages;
  MessagesBatchReceivedEvent(this.chatId, this.messages);
}

/// Emitted when a message's photo finishes downloading.
class MessagePhotoUpdatedEvent extends MessageEvent {
  final int chatId;
  final int messageId;
  final String photoPath;
  MessagePhotoUpdatedEvent(this.chatId, this.messageId, this.photoPath);
}

/// Emitted when a message's sticker finishes downloading.
class MessageStickerUpdatedEvent extends MessageEvent {
  final int chatId;
  final int messageId;
  final String stickerPath;
  MessageStickerUpdatedEvent(this.chatId, this.messageId, this.stickerPath);
}
