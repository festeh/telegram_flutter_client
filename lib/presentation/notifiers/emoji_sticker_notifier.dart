import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/repositories/telegram_client_repository.dart';
import '../../domain/entities/sticker.dart';
import '../state/emoji_sticker_state.dart';
import '../providers/telegram_client_provider.dart';

class EmojiStickerNotifier extends Notifier<EmojiStickerState> {
  late final TelegramClientRepository _client;

  @override
  EmojiStickerState build() {
    _client = ref.read(telegramClientProvider);
    return EmojiStickerState.initial();
  }

  void togglePicker() {
    state = state.copyWith(isPickerVisible: !state.isPickerVisible);

    // Load sticker sets when picker opens for the first time
    if (state.isPickerVisible &&
        state.installedStickerSets.isEmpty &&
        !state.isLoadingStickerSets) {
      loadInstalledStickerSets();
    }
  }

  void showPicker() {
    state = state.copyWith(isPickerVisible: true);

    // Load sticker sets when picker opens for the first time
    if (state.installedStickerSets.isEmpty && !state.isLoadingStickerSets) {
      loadInstalledStickerSets();
    }
  }

  void hidePicker() {
    state = state.copyWith(isPickerVisible: false);
  }

  void selectTab(PickerTab tab) {
    state = state.copyWith(selectedTab: tab);

    // Load sticker sets when switching to sticker tab
    if (tab == PickerTab.sticker &&
        state.installedStickerSets.isEmpty &&
        !state.isLoadingStickerSets) {
      loadInstalledStickerSets();
    }
  }

  void setKeyboardHeight(double height) {
    if (height > 0 && height != state.keyboardHeight) {
      state = state.copyWith(keyboardHeight: height);
    }
  }

  Future<void> loadInstalledStickerSets() async {
    if (state.isLoadingStickerSets) return;

    debugPrint('[EmojiStickerNotifier] loadInstalledStickerSets called');
    state = state.copyWith(isLoadingStickerSets: true, clearError: true);

    try {
      debugPrint('[EmojiStickerNotifier] Calling _client.getInstalledStickerSets()...');
      final stickerSets = await _client.getInstalledStickerSets();
      debugPrint('[EmojiStickerNotifier] Got ${stickerSets.length} sticker sets');

      // Also load recent stickers
      debugPrint('[EmojiStickerNotifier] Calling _client.getRecentStickers()...');
      final recentStickers = await _client.getRecentStickers();
      debugPrint('[EmojiStickerNotifier] Got ${recentStickers.length} recent stickers');

      state = state.copyWith(
        installedStickerSets: stickerSets,
        recentStickers: recentStickers,
        isLoadingStickerSets: false,
      );
      debugPrint('[EmojiStickerNotifier] State updated with sticker sets');
    } catch (e) {
      debugPrint('[EmojiStickerNotifier] Error loading sticker sets: $e');
      state = state.copyWith(
        isLoadingStickerSets: false,
        errorMessage: 'Failed to load sticker sets: $e',
      );
    }
  }

  Future<void> selectStickerSet(StickerSet stickerSet) async {
    // If already selected, deselect (show recent)
    if (state.selectedStickerSet?.id == stickerSet.id) {
      state = state.copyWith(clearSelectedSet: true);
      return;
    }

    // If this set doesn't have full stickers loaded, load them
    if (stickerSet.stickers.isEmpty || stickerSet.stickers.length <= 5) {
      state = state.copyWith(isLoadingStickers: true);

      try {
        final fullSet = await _client.getStickerSet(stickerSet.id);
        if (fullSet != null) {
          // Update the set in our list
          final updatedSets = state.installedStickerSets.map((s) {
            return s.id == fullSet.id ? fullSet : s;
          }).toList();

          state = state.copyWith(
            installedStickerSets: updatedSets,
            selectedStickerSet: fullSet,
            isLoadingStickers: false,
          );
        } else {
          state = state.copyWith(
            selectedStickerSet: stickerSet,
            isLoadingStickers: false,
          );
        }
      } catch (e) {
        state = state.copyWith(
          isLoadingStickers: false,
          errorMessage: 'Failed to load stickers: $e',
        );
      }
    } else {
      state = state.copyWith(selectedStickerSet: stickerSet);
    }
  }

  Future<void> sendSticker(int chatId, Sticker sticker) async {
    try {
      await _client.sendSticker(chatId, sticker);
      // Optionally hide picker after sending
      // hidePicker();
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Failed to send sticker: $e',
      );
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }
}
