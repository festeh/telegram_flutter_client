import '../../domain/entities/sticker.dart';

enum PickerTab { emoji, sticker }

class EmojiStickerState {
  final bool isPickerVisible;
  final PickerTab selectedTab;
  final List<StickerSet> installedStickerSets;
  final List<Sticker> recentStickers;
  final StickerSet? selectedStickerSet;
  final bool isLoadingStickerSets;
  final bool isLoadingStickers;
  final String? errorMessage;
  final double keyboardHeight;
  // Centralized sticker download path tracking (fileId -> localPath)
  final Map<int, String> stickerDownloadPaths;

  const EmojiStickerState({
    this.isPickerVisible = false,
    this.selectedTab = PickerTab.emoji,
    this.installedStickerSets = const [],
    this.recentStickers = const [],
    this.selectedStickerSet,
    this.isLoadingStickerSets = false,
    this.isLoadingStickers = false,
    this.errorMessage,
    this.keyboardHeight = 300.0,
    this.stickerDownloadPaths = const {},
  });

  factory EmojiStickerState.initial() => const EmojiStickerState();

  EmojiStickerState copyWith({
    bool? isPickerVisible,
    PickerTab? selectedTab,
    List<StickerSet>? installedStickerSets,
    List<Sticker>? recentStickers,
    StickerSet? selectedStickerSet,
    bool? isLoadingStickerSets,
    bool? isLoadingStickers,
    String? errorMessage,
    double? keyboardHeight,
    Map<int, String>? stickerDownloadPaths,
    bool clearSelectedSet = false,
    bool clearError = false,
  }) {
    return EmojiStickerState(
      isPickerVisible: isPickerVisible ?? this.isPickerVisible,
      selectedTab: selectedTab ?? this.selectedTab,
      installedStickerSets: installedStickerSets ?? this.installedStickerSets,
      recentStickers: recentStickers ?? this.recentStickers,
      selectedStickerSet: clearSelectedSet
          ? null
          : (selectedStickerSet ?? this.selectedStickerSet),
      isLoadingStickerSets: isLoadingStickerSets ?? this.isLoadingStickerSets,
      isLoadingStickers: isLoadingStickers ?? this.isLoadingStickers,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      keyboardHeight: keyboardHeight ?? this.keyboardHeight,
      stickerDownloadPaths: stickerDownloadPaths ?? this.stickerDownloadPaths,
    );
  }

  /// Get the local path for a sticker by its file ID
  String? getStickerPath(int fileId) => stickerDownloadPaths[fileId];

  /// Returns the currently displayed stickers (from selected set or recent)
  List<Sticker> get displayedStickers {
    if (selectedStickerSet != null) {
      return selectedStickerSet!.stickers;
    }
    return recentStickers;
  }

  @override
  String toString() {
    return 'EmojiStickerState(visible: $isPickerVisible, tab: $selectedTab, sets: ${installedStickerSets.length})';
  }
}
