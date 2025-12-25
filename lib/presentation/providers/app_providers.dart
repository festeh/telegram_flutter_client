import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../notifiers/auth_notifier.dart';
import '../notifiers/chat_notifier.dart';
import '../notifiers/message_notifier.dart';
import '../notifiers/emoji_sticker_notifier.dart';
import '../state/unified_auth_state.dart';
import '../state/chat_state.dart';
import '../state/message_state.dart';
import '../state/emoji_sticker_state.dart';
import '../../domain/entities/chat.dart';
import '../../domain/entities/sticker.dart';

// Single source of truth for all authentication state
final authProvider = AsyncNotifierProvider<AuthNotifier, UnifiedAuthState>(
  () => AuthNotifier(),
);

// Single source of truth for all chat state
final chatProvider = AsyncNotifierProvider<ChatNotifier, ChatState>(
  () => ChatNotifier(),
);

// Single source of truth for all message state
final messageProvider = AsyncNotifierProvider<MessageNotifier, MessageState>(
  () => MessageNotifier(),
);

// Single source of truth for emoji/sticker picker state
final emojiStickerProvider = NotifierProvider<EmojiStickerNotifier, EmojiStickerState>(
  () => EmojiStickerNotifier(),
);

// Clean extension methods for convenient UI access
extension AuthX on WidgetRef {
  // State access
  UnifiedAuthState? get auth => watch(authProvider).value;
  bool get isAuthLoading => watch(authProvider).isLoading;
  bool get hasAuthError => watch(authProvider).hasError;
  String? get authError => watch(authProvider).error?.toString();

  // Computed properties - these will trigger rebuilds only when specific values change
  bool get isAuthenticated => watch(authProvider
      .select((state) => state.value?.isAuthenticated ?? false));

  bool get needsPhoneNumber => watch(authProvider
      .select((state) => state.value?.needsPhoneNumber ?? false));

  bool get needsCode => watch(
      authProvider.select((state) => state.value?.needsCode ?? false));

  bool get needsPassword => watch(authProvider
      .select((state) => state.value?.needsPassword ?? false));

  bool get needsRegistration => watch(authProvider
      .select((state) => state.value?.needsRegistration ?? false));

  bool get needsQrConfirmation => watch(authProvider
      .select((state) => state.value?.needsQrConfirmation ?? false));

  bool get isLoading => watch(
      authProvider.select((state) => state.value?.isLoading ?? false));

  String? get errorMessage =>
      watch(authProvider.select((state) => state.value?.errorMessage));

  // User info access
  dynamic get currentUser =>
      watch(authProvider.select((state) => state.value?.user));

  // Additional auth info
  dynamic get codeInfo =>
      watch(authProvider.select((state) => state.value?.codeInfo));

  dynamic get qrCodeInfo =>
      watch(authProvider.select((state) => state.value?.qrCodeInfo));

  // Action shortcuts - these don't trigger rebuilds
  AuthNotifier get authActions => read(authProvider.notifier);

  // Convenience action methods
  Future<void> submitPhoneNumber(String phone) =>
      authActions.submitPhoneNumber(phone);

  Future<void> submitVerificationCode(String code) =>
      authActions.submitVerificationCode(code);

  Future<void> submitPassword(String password) =>
      authActions.submitPassword(password);

  Future<void> requestQrCode() => authActions.requestQrCode();

  Future<void> resendCode() => authActions.resendCode();

  Future<void> registerUser(String firstName, String lastName) =>
      authActions.registerUser(firstName, lastName);

  Future<void> logout() => authActions.logout();

  void clearError() => authActions.clearError();
}

// Chat extension methods for convenient UI access
extension ChatX on WidgetRef {
  // State access
  ChatState? get chatState => watch(chatProvider).value;
  bool get isChatLoading => watch(chatProvider).isLoading;
  bool get hasChatError => watch(chatProvider).hasError;
  String? get chatError => watch(chatProvider).error?.toString();

  // Computed properties
  List<Chat> get chats =>
      watch(chatProvider.select((state) => state.value?.chats ?? []));
  int get chatCount =>
      watch(chatProvider.select((state) => state.value?.chatCount ?? 0));
  bool get hasChats => watch(chatProvider
      .select((state) => state.value?.chats.isNotEmpty ?? false));

  // Action shortcuts
  ChatNotifier get chatActions => read(chatProvider.notifier);

  // Convenience action methods
  Future<void> refreshChats() => chatActions.refreshChats();
  Future<void> loadMoreChats() => chatActions.loadMoreChats();
  void clearChatError() => chatActions.clearError();
}

// Message extension methods for convenient UI access
extension MessageX on WidgetRef {
  // State access
  MessageState? get messageState => watch(messageProvider).value;
  bool get isMessageLoading => watch(messageProvider).isLoading;
  bool get hasMessageError => watch(messageProvider).hasError;
  String? get messageError => watch(messageProvider).error?.toString();

  // Computed properties
  Map<int, List<Message>> get messagesByChat =>
      watch(messageProvider.select((state) => state.value?.messagesByChat ?? {}));
  
  List<Message> get selectedChatMessages =>
      watch(messageProvider.select((state) => state.value?.selectedChatMessages ?? []));
  
  int? get selectedChatId =>
      watch(messageProvider.select((state) => state.value?.selectedChatId));
  
  bool get hasSelectedChat =>
      watch(messageProvider.select((state) => state.value?.hasSelectedChat ?? false));
  
  bool get selectedChatHasMessages =>
      watch(messageProvider.select((state) => state.value?.selectedChatHasMessages ?? false));
  
  bool get isLoadingMore =>
      watch(messageProvider.select((state) => state.value?.isLoadingMore ?? false));
  
  bool get isSending =>
      watch(messageProvider.select((state) => state.value?.isSending ?? false));

  // Action shortcuts
  MessageNotifier get messageActions => read(messageProvider.notifier);

  // Convenience action methods
  Future<void> loadMessages(int chatId, {bool forceRefresh = false}) =>
      messageActions.loadMessages(chatId, forceRefresh: forceRefresh);
  
  Future<void> loadMoreMessages(int chatId) =>
      messageActions.loadMoreMessages(chatId);
  
  Future<void> sendMessage(int chatId, String text) =>
      messageActions.sendMessage(chatId, text);
  
  Future<void> editMessage(int chatId, int messageId, String newText) =>
      messageActions.editMessage(chatId, messageId, newText);
  
  Future<void> deleteMessage(int chatId, int messageId) =>
      messageActions.deleteMessage(chatId, messageId);
  
  Future<void> markAsRead(int chatId, int messageId) =>
      messageActions.markAsRead(chatId, messageId);
  
  void selectChatForMessages(int chatId) => messageActions.selectChat(chatId);
  void clearMessageError() => messageActions.clearError();
}

// Emoji/Sticker picker extension methods
extension EmojiStickerX on WidgetRef {
  // State access
  EmojiStickerState get emojiStickerState => watch(emojiStickerProvider);

  // Computed properties
  bool get isPickerVisible =>
      watch(emojiStickerProvider.select((state) => state.isPickerVisible));

  PickerTab get selectedPickerTab =>
      watch(emojiStickerProvider.select((state) => state.selectedTab));

  List<StickerSet> get installedStickerSets =>
      watch(emojiStickerProvider.select((state) => state.installedStickerSets));

  List<Sticker> get recentStickers =>
      watch(emojiStickerProvider.select((state) => state.recentStickers));

  StickerSet? get selectedStickerSet =>
      watch(emojiStickerProvider.select((state) => state.selectedStickerSet));

  List<Sticker> get displayedStickers =>
      watch(emojiStickerProvider.select((state) => state.displayedStickers));

  bool get isLoadingStickerSets =>
      watch(emojiStickerProvider.select((state) => state.isLoadingStickerSets));

  bool get isLoadingStickers =>
      watch(emojiStickerProvider.select((state) => state.isLoadingStickers));

  double get pickerKeyboardHeight =>
      watch(emojiStickerProvider.select((state) => state.keyboardHeight));

  // Action shortcuts
  EmojiStickerNotifier get emojiStickerActions => read(emojiStickerProvider.notifier);

  // Convenience action methods
  void toggleEmojiPicker() => emojiStickerActions.togglePicker();
  void showEmojiPicker() => emojiStickerActions.showPicker();
  void hideEmojiPicker() => emojiStickerActions.hidePicker();
  void selectPickerTab(PickerTab tab) => emojiStickerActions.selectTab(tab);
  void setPickerKeyboardHeight(double height) => emojiStickerActions.setKeyboardHeight(height);
  Future<void> loadStickerSets() => emojiStickerActions.loadInstalledStickerSets();
  Future<void> selectStickerSet(StickerSet set) => emojiStickerActions.selectStickerSet(set);
  Future<void> sendSticker(int chatId, Sticker sticker) => emojiStickerActions.sendSticker(chatId, sticker);
}

// Legacy provider names for backward compatibility during migration (optional)
// These can be removed once all widgets are updated
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider
      .select((state) => state.value?.isAuthenticated ?? false));
});
