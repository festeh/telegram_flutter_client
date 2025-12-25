import 'dart:io';
import 'package:flutter/material.dart';

class PhotoMessageWidget extends StatelessWidget {
  final String? photoPath;
  final int? photoWidth;
  final int? photoHeight;
  final bool isOutgoing;

  const PhotoMessageWidget({
    super.key,
    this.photoPath,
    this.photoWidth,
    this.photoHeight,
    required this.isOutgoing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate constrained dimensions
    const maxWidth = 250.0;
    const maxHeight = 300.0;

    final (displayWidth, displayHeight) = _calculateDimensions(maxWidth, maxHeight);
    final path = photoPath;
    final hasPhoto = path != null && path.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: displayWidth ?? 200,
        height: displayHeight ?? 150,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
        ),
        child: hasPhoto ? _buildImage() : _buildPlaceholder(context),
      ),
    );
  }

  (double, double) _calculateDimensions(double maxWidth, double maxHeight) {
    final w = photoWidth;
    final h = photoHeight;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return (200.0, 150.0);
    }

    final aspectRatio = w / h;
    double displayWidth;
    double displayHeight;

    if (aspectRatio > 1) {
      // Landscape
      displayWidth = maxWidth;
      displayHeight = maxWidth / aspectRatio;
      if (displayHeight > maxHeight) {
        displayHeight = maxHeight;
        displayWidth = maxHeight * aspectRatio;
      }
    } else {
      // Portrait or square
      displayHeight = maxHeight;
      displayWidth = maxHeight * aspectRatio;
      if (displayWidth > maxWidth) {
        displayWidth = maxWidth;
        displayHeight = maxWidth / aspectRatio;
      }
    }
    return (displayWidth, displayHeight);
  }

  Widget _buildImage() {
    final path = photoPath;
    if (path == null) return const SizedBox.shrink();

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder(context);
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo,
            size: 40,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Photo',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}
