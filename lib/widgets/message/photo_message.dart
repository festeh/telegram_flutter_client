import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  void _openFullScreen(BuildContext context) {
    final path = photoPath;
    if (path == null || path.isEmpty) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullScreenImageViewer(imagePath: path);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate constrained dimensions
    const maxWidth = 250.0;
    const maxHeight = 300.0;

    final (displayWidth, displayHeight) = _calculateDimensions(maxWidth, maxHeight);
    final path = photoPath;
    final hasPhoto = path != null && path.isNotEmpty;

    return GestureDetector(
      onTap: hasPhoto ? () => _openFullScreen(context) : null,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: displayWidth,
          height: displayHeight,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
          ),
          child: hasPhoto ? _buildImage() : _buildPlaceholder(context),
        ),
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

class _FullScreenImageViewer extends StatefulWidget {
  final String imagePath;

  const _FullScreenImageViewer({required this.imagePath});

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final TransformationController _transformationController = TransformationController();
  double _dragOffset = 0;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
            _close();
          }
        },
        child: GestureDetector(
          onTap: _close,
          onVerticalDragUpdate: (details) {
            setState(() {
              _dragOffset += details.delta.dy;
            });
          },
          onVerticalDragEnd: (details) {
            if (_dragOffset.abs() > 100) {
              _close();
            } else {
              setState(() {
                _dragOffset = 0;
              });
            }
          },
          child: Container(
            color: Colors.black.withValues(alpha: (1 - (_dragOffset.abs() / 300)).clamp(0.7, 1.0)),
            child: Stack(
              children: [
                Center(
                  child: Transform.translate(
                    offset: Offset(0, _dragOffset),
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 16,
                  child: IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
