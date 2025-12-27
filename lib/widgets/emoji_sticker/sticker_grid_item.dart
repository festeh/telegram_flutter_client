import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../domain/entities/sticker.dart';
import '../../data/repositories/tdlib_telegram_client.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/providers/telegram_client_provider.dart';

class StickerGridItem extends ConsumerStatefulWidget {
  final Sticker sticker;
  final double size;
  final VoidCallback? onTap;

  const StickerGridItem({
    super.key,
    required this.sticker,
    required this.size,
    this.onTap,
  });

  @override
  ConsumerState<StickerGridItem> createState() => _StickerGridItemState();
}

class _StickerGridItemState extends ConsumerState<StickerGridItem> {
  LottieComposition? _composition;
  bool _loadError = false;
  bool _isLoading = false;
  bool _downloadRequested = false;

  @override
  void initState() {
    super.initState();
    _initSticker();
  }

  @override
  void didUpdateWidget(StickerGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sticker.id != widget.sticker.id) {
      _composition = null;
      _loadError = false;
      _isLoading = false;
      _downloadRequested = false;
      _initSticker();
    }
  }

  void _initSticker() {
    // First check if sticker already has a local path
    if (widget.sticker.localPath != null &&
        widget.sticker.localPath!.isNotEmpty) {
      _loadSticker(widget.sticker.localPath!);
      return;
    }

    // Check the centralized download paths
    final downloadPath = ref
        .read(emojiStickerProvider)
        .getStickerPath(widget.sticker.fileId);
    if (downloadPath != null) {
      _loadSticker(downloadPath);
      return;
    }

    // Check cache before requesting download
    if (widget.sticker.fileId > 0) {
      final client = ref.read(telegramClientProvider);
      if (client is TdlibTelegramClient) {
        final cachedPath = client.getCachedStickerPath(widget.sticker.fileId);
        if (cachedPath != null) {
          _loadSticker(cachedPath);
          return;
        }
      }

      if (!_downloadRequested) {
        _requestDownload();
      }
    }
  }

  void _requestDownload() {
    _downloadRequested = true;
    ref
        .read(emojiStickerProvider.notifier)
        .requestStickerDownload(widget.sticker.fileId);
  }

  Future<void> _loadSticker(String path) async {
    if (path.isEmpty) return;
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _loadError = true;
            _isLoading = false;
          });
        }
        return;
      }

      if (widget.sticker.isAnimated) {
        final bytes = await file.readAsBytes();
        // TGS files are gzip-compressed Lottie JSON
        final composition = await LottieComposition.decodeGZip(bytes);
        if (mounted) {
          setState(() {
            _composition = composition;
            _loadError = false;
            _isLoading = false;
          });
        }
      } else {
        // Static sticker - just mark as loaded
        if (mounted) {
          setState(() {
            _loadError = false;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading sticker: $e');
      if (mounted) {
        setState(() {
          _loadError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch for download path updates from the centralized provider
    final downloadPath = ref.watch(
      emojiStickerProvider.select(
        (state) => state.getStickerPath(widget.sticker.fileId),
      ),
    );

    // Determine the effective path
    final effectivePath = widget.sticker.localPath ?? downloadPath;
    final hasPath = effectivePath != null && effectivePath.isNotEmpty;

    // If we got a new download path, trigger loading
    if (downloadPath != null &&
        _composition == null &&
        !_isLoading &&
        !_loadError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSticker(downloadPath);
      });
    }

    Widget content;

    if (_isLoading || (_downloadRequested && !hasPath)) {
      content = _buildLoadingIndicator();
    } else if (!hasPath || _loadError) {
      content = _buildPlaceholder(context);
    } else if (widget.sticker.isAnimated) {
      content = _buildAnimatedSticker(effectivePath);
    } else {
      content = _buildStaticSticker(effectivePath);
    }

    if (widget.onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(padding: const EdgeInsets.all(4), child: content),
        ),
      );
    }

    return content;
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  Widget _buildAnimatedSticker(String? path) {
    if (_composition != null) {
      return Lottie(composition: _composition, fit: BoxFit.contain);
    }

    // Still loading
    if (_isLoading) {
      return _buildLoadingIndicator();
    }

    return _buildPlaceholder(context);
  }

  Widget _buildStaticSticker(String? path) {
    if (path == null) return _buildPlaceholder(context);

    return Image.file(
      File(path),
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return _buildPlaceholder(context);
      },
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    // Show emoji if available
    if (widget.sticker.emoji.isNotEmpty) {
      return Center(
        child: Text(
          widget.sticker.emoji,
          style: TextStyle(fontSize: widget.size > 40 ? 32 : 20),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Icon(
        Icons.sticky_note_2_outlined,
        size: widget.size > 40 ? 24 : 16,
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
