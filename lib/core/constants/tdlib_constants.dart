// Constants for TDLib update types and other magic strings.
// Using constants prevents typos and enables IDE autocomplete.

/// TDLib update type names.
abstract class TdlibUpdateTypes {
  static const authorizationState = 'updateAuthorizationState';
  static const user = 'updateUser';
  static const newChat = 'updateNewChat';
  static const chatLastMessage = 'updateChatLastMessage';
  static const newMessage = 'updateNewMessage';
  static const message = 'message';
  static const messages = 'messages';
  static const messageEdited = 'updateMessageEdited';
  static const deleteMessages = 'updateDeleteMessages';
  static const messageContent = 'updateMessageContent';
  static const messageSendSucceeded = 'updateMessageSendSucceeded';
  static const messageSendFailed = 'updateMessageSendFailed';
  static const file = 'updateFile';
  static const chatTitle = 'updateChatTitle';
  static const chatPhoto = 'updateChatPhoto';
  static const chatOrder = 'updateChatOrder';
  static const chatReadInbox = 'updateChatReadInbox';
  static const chatPosition = 'updateChatPosition';
}

/// TDLib chat list type names.
abstract class TdlibChatListTypes {
  static const main = 'chatListMain';
  static const archive = 'chatListArchive';
  static const folder = 'chatListFolder';
}

/// TDLib JSON field names.
abstract class TdlibFields {
  static const type = '@type';
  static const chatId = 'chat_id';
  static const messageId = 'message_id';
  static const messageIds = 'message_ids';
  static const fromCache = 'from_cache';
  static const isSelf = 'is_self';
}
