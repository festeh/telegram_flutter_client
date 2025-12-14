import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/providers/app_providers.dart';
import '../../domain/entities/sticker.dart';
import 'sticker_grid_item.dart';

class StickerTab extends ConsumerStatefulWidget {
  final int chatId;
  final VoidCallback? onStickerSent;

  const StickerTab({
    super.key,
    required this.chatId,
    this.onStickerSent,
  });

  @override
  ConsumerState<StickerTab> createState() => _StickerTabState();
}

class _StickerTabState extends ConsumerState<StickerTab> {
  @override
  void initState() {
    super.initState();
    // Load sticker sets if not already loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(emojiStickerProvider);
      if (state.installedStickerSets.isEmpty && !state.isLoadingStickerSets) {
        ref.read(emojiStickerProvider.notifier).loadInstalledStickerSets();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final stickerSets = ref.watch(emojiStickerProvider.select((s) => s.installedStickerSets));
    final recentStickers = ref.watch(emojiStickerProvider.select((s) => s.recentStickers));
    final selectedSet = ref.watch(emojiStickerProvider.select((s) => s.selectedStickerSet));
    final isLoadingSets = ref.watch(emojiStickerProvider.select((s) => s.isLoadingStickerSets));
    final isLoadingStickers = ref.watch(emojiStickerProvider.select((s) => s.isLoadingStickers));
    final displayedStickers = ref.watch(emojiStickerProvider.select((s) => s.displayedStickers));

    return Column(
      children: [
        // Sticker set selector bar
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: isLoadingSets
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _buildStickerSetBar(stickerSets, selectedSet, recentStickers.isNotEmpty),
        ),
        // Sticker grid
        Expanded(
          child: isLoadingStickers
              ? const Center(child: CircularProgressIndicator())
              : displayedStickers.isEmpty
                  ? _buildEmptyState(colorScheme, selectedSet == null)
                  : _buildStickerGrid(displayedStickers),
        ),
      ],
    );
  }

  Widget _buildStickerSetBar(
    List<StickerSet> stickerSets,
    StickerSet? selectedSet,
    bool hasRecent,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      itemCount: stickerSets.length + 1, // +1 for recent tab
      itemBuilder: (context, index) {
        if (index == 0) {
          // Recent stickers tab
          final isSelected = selectedSet == null;
          return _StickerSetIcon(
            isSelected: isSelected,
            onTap: () {
              if (selectedSet != null) {
                // Deselect current set to show recent
                ref.read(emojiStickerProvider.notifier).selectStickerSet(selectedSet);
              }
            },
            child: Icon(
              Icons.access_time,
              size: 24,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
          );
        }

        final set = stickerSets[index - 1];
        final isSelected = selectedSet?.id == set.id;

        return _StickerSetIcon(
          isSelected: isSelected,
          onTap: () => ref.read(emojiStickerProvider.notifier).selectStickerSet(set),
          child: set.stickers.isNotEmpty
              ? StickerGridItem(
                  sticker: set.stickers.first,
                  size: 32,
                  onTap: null,
                )
              : Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text(
                      set.title.isNotEmpty ? set.title[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, bool isRecent) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isRecent ? Icons.history : Icons.sticky_note_2_outlined,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 8),
          Text(
            isRecent ? 'No recent stickers' : 'No stickers in this set',
            style: TextStyle(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickerGrid(List<Sticker> stickers) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        return StickerGridItem(
          sticker: sticker,
          size: double.infinity,
          onTap: () => _sendSticker(sticker),
        );
      },
    );
  }

  void _sendSticker(Sticker sticker) {
    ref.read(emojiStickerProvider.notifier).sendSticker(widget.chatId, sticker);
    widget.onStickerSent?.call();
  }
}

class _StickerSetIcon extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _StickerSetIcon({
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 40,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: colorScheme.primary, width: 1.5)
                  : null,
            ),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
