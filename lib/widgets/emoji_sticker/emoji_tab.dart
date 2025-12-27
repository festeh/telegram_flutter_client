import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class EmojiTab extends StatelessWidget {
  final TextEditingController textController;
  final VoidCallback? onEmojiSelected;

  const EmojiTab({
    super.key,
    required this.textController,
    this.onEmojiSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return EmojiPicker(
      textEditingController: textController,
      onEmojiSelected: (category, emoji) {
        onEmojiSelected?.call();
      },
      config: Config(
        height: double.infinity,
        checkPlatformCompatibility: true,
        emojiViewConfig: EmojiViewConfig(
          columns: 8,
          emojiSizeMax: 28,
          verticalSpacing: 0,
          horizontalSpacing: 0,
          gridPadding: EdgeInsets.zero,
          backgroundColor: colorScheme.surface,
          noRecents: const Text('No Recents', style: TextStyle(fontSize: 16)),
          loadingIndicator: const Center(child: CircularProgressIndicator()),
          buttonMode: ButtonMode.MATERIAL,
        ),
        skinToneConfig: const SkinToneConfig(),
        categoryViewConfig: CategoryViewConfig(
          initCategory: Category.RECENT,
          backgroundColor: colorScheme.surfaceContainerLow,
          indicatorColor: colorScheme.primary,
          iconColor: colorScheme.onSurfaceVariant,
          iconColorSelected: colorScheme.primary,
          backspaceColor: colorScheme.primary,
          categoryIcons: const CategoryIcons(),
          customCategoryView: (config, state, tabController, pageController) {
            return _CustomCategoryView(
              config: config,
              state: state,
              tabController: tabController,
              pageController: pageController,
              colorScheme: colorScheme,
            );
          },
        ),
        bottomActionBarConfig: BottomActionBarConfig(
          enabled: true,
          showBackspaceButton: true,
          showSearchViewButton: true,
          backgroundColor: colorScheme.surfaceContainerLow,
          buttonColor: colorScheme.onSurfaceVariant,
          buttonIconColor: colorScheme.onSurfaceVariant,
        ),
        searchViewConfig: SearchViewConfig(
          backgroundColor: colorScheme.surface,
          buttonIconColor: colorScheme.onSurfaceVariant,
          hintText: 'Search emoji',
        ),
      ),
    );
  }
}

class _CustomCategoryView extends StatelessWidget {
  final Config config;
  final EmojiViewState state;
  final TabController tabController;
  final PageController pageController;
  final ColorScheme colorScheme;

  const _CustomCategoryView({
    required this.config,
    required this.state,
    required this.tabController,
    required this.pageController,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colorScheme.surfaceContainerLow,
      child: TabBar(
        controller: tabController,
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        onTap: (index) {
          pageController.jumpToPage(index);
        },
        tabs: Category.values.map((category) {
          return Tab(icon: Icon(_getCategoryIcon(category), size: 20));
        }).toList(),
      ),
    );
  }

  IconData _getCategoryIcon(Category category) {
    switch (category) {
      case Category.RECENT:
        return Icons.access_time;
      case Category.SMILEYS:
        return Icons.emoji_emotions_outlined;
      case Category.ANIMALS:
        return Icons.pets_outlined;
      case Category.FOODS:
        return Icons.fastfood_outlined;
      case Category.TRAVEL:
        return Icons.directions_car_outlined;
      case Category.ACTIVITIES:
        return Icons.sports_soccer_outlined;
      case Category.OBJECTS:
        return Icons.lightbulb_outline;
      case Category.SYMBOLS:
        return Icons.emoji_symbols_outlined;
      case Category.FLAGS:
        return Icons.flag_outlined;
    }
  }
}
