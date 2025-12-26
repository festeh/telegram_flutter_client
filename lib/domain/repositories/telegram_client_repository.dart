import 'dart:async';
import '../entities/auth_state.dart';
import '../entities/user_session.dart';
import '../entities/chat.dart';
import '../entities/sticker.dart';
import '../events/chat_events.dart';
import '../events/message_events.dart';

abstract class TelegramClientRepository {
  Stream<Map<String, dynamic>> get updates;
  Stream<AuthenticationState> get authUpdates;
  Stream<ChatEvent> get chatEvents;
  Stream<MessageEvent> get messageEvents;

  AuthenticationState get currentAuthState;
  UserSession? get currentUser;

  Future<void> start();

  // Authentication methods
  Future<void> setPhoneNumber(String phoneNumber);
  Future<void> checkAuthenticationCode(String code);
  Future<void> checkAuthenticationPassword(String password);
  Future<void> requestQrCodeAuthentication();
  Future<void> confirmQrCodeAuthentication(String link);
  Future<void> registerUser(String firstName, String lastName);
  Future<void> resendAuthenticationCode();
  Future<void> logOut();

  // Chat methods
  Future<List<Chat>> loadChats(
      {int limit = 20, int offsetOrder = 0, int offsetChatId = 0});
  Future<Chat?> getChat(int chatId);

  // User methods
  String? getUserStatus(int userId);

  // File methods
  Future<void> downloadFile(int fileId);

  // Message methods
  Future<List<Message>> loadMessages(int chatId, {int limit = 50, int fromMessageId = 0});
  Future<Message?> sendMessage(int chatId, String text, {int? replyToMessageId});
  Future<void> sendPhoto(int chatId, String filePath, {String? caption, int? replyToMessageId});
  Future<void> sendVideo(int chatId, String filePath, {String? caption, int? replyToMessageId});
  Future<void> sendDocument(int chatId, String filePath, {String? caption, int? replyToMessageId});
  Future<void> markAsRead(int chatId, int messageId);
  Future<bool> deleteMessage(int chatId, int messageId);
  Future<Message?> editMessage(int chatId, int messageId, String newText);

  // Reaction methods
  Future<void> addReaction(int chatId, int messageId, MessageReaction reaction);
  Future<void> removeReaction(int chatId, int messageId, MessageReaction reaction);

  // Sticker methods
  Future<List<StickerSet>> getInstalledStickerSets();
  Future<StickerSet?> getStickerSet(int setId);
  Future<List<Sticker>> getRecentStickers();
  Future<void> sendSticker(int chatId, Sticker sticker);

  void dispose();
}
