import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class StickerMessageWidget extends StatefulWidget {
  final String? stickerPath;
  final int? stickerWidth;
  final int? stickerHeight;
  final bool isAnimated;
  final String? emoji;

  const StickerMessageWidget({
    super.key,
    this.stickerPath,
    this.stickerWidth,
    this.stickerHeight,
    this.isAnimated = false,
    this.emoji,
  });

  @override
  State<StickerMessageWidget> createState() => _StickerMessageWidgetState();
}

class _StickerMessageWidgetState extends State<StickerMessageWidget> {
  LottieComposition? _composition;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _loadSticker();
  }

  @override
  void didUpdateWidget(StickerMessageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stickerPath != widget.stickerPath) {
      _loadSticker();
    }
  }

  Future<void> _loadSticker() async {
    final path = widget.stickerPath;
    if (!widget.isAnimated || path == null || path.isEmpty) {
      return;
    }

    try {
      final file = File(path);
      if (!await file.exists()) {
        setState(() => _loadError = true);
        return;
      }

      final bytes = await file.readAsBytes();
      // TGS files are gzip-compressed Lottie JSON
      final composition = await LottieComposition.decodeGZip(bytes);
      if (mounted) {
        setState(() {
          _composition = composition;
          _loadError = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading TGS sticker: $e');
      if (mounted) {
        setState(() => _loadError = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stickers are typically 512x512, constrain to 150x150 max
    const maxSize = 150.0;

    final path = widget.stickerPath;
    final hasSticker = path != null && path.isNotEmpty;

    return SizedBox(
      width: maxSize,
      height: maxSize,
      child: hasSticker && !_loadError ? _buildSticker(path) : _buildPlaceholder(context),
    );
  }

  Widget _buildSticker(String path) {
    if (widget.isAnimated) {
      // TGS files - use pre-loaded composition
      if (_composition != null) {
        return Lottie(
          composition: _composition,
          fit: BoxFit.contain,
        );
      }
      // Still loading
      return _buildPlaceholder(context);
    } else {
      // Static WebP sticker
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(context);
        },
      );
    }
  }

  Widget _buildPlaceholder(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Show emoji if available, otherwise generic sticker icon
    final emoji = widget.emoji;
    if (emoji != null && emoji.isNotEmpty) {
      return Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 80),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_emotions_outlined,
            size: 40,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 8),
          Text(
            'Sticker',
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
