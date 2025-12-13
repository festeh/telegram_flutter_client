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
    final maxWidth = 250.0;
    final maxHeight = 300.0;

    double? displayWidth;
    double? displayHeight;

    if (photoWidth != null && photoHeight != null && photoWidth! > 0 && photoHeight! > 0) {
      final aspectRatio = photoWidth! / photoHeight!;

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
    }

    final hasPhoto = photoPath != null && photoPath!.isNotEmpty;

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

  Widget _buildImage() {
    return Image.file(
      File(photoPath!),
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
