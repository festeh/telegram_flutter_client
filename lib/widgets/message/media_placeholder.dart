import 'package:flutter/material.dart';
import '../../core/constants/ui_constants.dart';

/// Reusable placeholder widget for media content (photos, videos, stickers).
///
/// Shows an icon and label centered in the available space.
class MediaPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;

  const MediaPlaceholder({super.key, required this.icon, required this.label});

  /// Photo placeholder with camera icon.
  const MediaPlaceholder.photo({super.key})
    : icon = Icons.photo,
      label = 'Photo';

  /// Video placeholder with videocam icon.
  const MediaPlaceholder.video({super.key})
    : icon = Icons.videocam,
      label = 'Video';

  /// Sticker placeholder with emoji icon.
  const MediaPlaceholder.sticker({super.key})
    : icon = Icons.emoji_emotions_outlined,
      label = 'Sticker';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: IconSize.lg,
            color: colorScheme.onSurface.withValues(alpha: Opacities.muted),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: Opacities.medium),
            ),
          ),
        ],
      ),
    );
  }
}
