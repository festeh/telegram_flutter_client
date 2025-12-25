import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import '../../domain/entities/sticker.dart';
import '../../data/repositories/tdlib_telegram_client.dart';
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
  String? _localPath;
  StreamSubscription? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _localPath = widget.sticker.localPath;
    _initSticker();
  }

  @override
  void didUpdateWidget(StickerGridItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sticker.localPath != widget.sticker.localPath ||
        oldWidget.sticker.id != widget.sticker.id) {
      _localPath = widget.sticker.localPath;
      _downloadRequested = false;
      _initSticker();
    }
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  void _initSticker() {
    if (_localPath != null && _localPath!.isNotEmpty) {
      _loadSticker();
      return;
    }

    // Check cache before requesting download
    if (widget.sticker.fileId > 0) {
      final client = ref.read(telegramClientProvider);
      if (client is TdlibTelegramClient) {
        final cachedPath = client.getCachedStickerPath(widget.sticker.fileId);
        if (cachedPath != null) {
          _localPath = cachedPath;
          _loadSticker();
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
    final client = ref.read(telegramClientProvider);

    // Listen for download completion
    if (client is TdlibTelegramClient) {
      _downloadSubscription?.cancel();
      _downloadSubscription = client.fileDownloads.listen((event) {
        if (event.fileId == widget.sticker.fileId && mounted) {
          setState(() {
            _localPath = event.path;
          });
          _loadSticker();
        }
      });

      // Request download
      client.downloadFile(widget.sticker.fileId);
    }
  }

  Future<void> _loadSticker() async {
    final path = _localPath;
    if (path == null || path.isEmpty) {
      return;
    }

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
    final path = _localPath;
    final hasPath = path != null && path.isNotEmpty;

    Widget content;

    if (_isLoading || (_downloadRequested && !hasPath)) {
      content = _buildLoadingIndicator();
    } else if (!hasPath || _loadError) {
      content = _buildPlaceholder(context);
    } else if (widget.sticker.isAnimated) {
      content = _buildAnimatedSticker();
    } else {
      content = _buildStaticSticker();
    }

    if (widget.onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: content,
          ),
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

  Widget _buildAnimatedSticker() {
    if (_composition != null) {
      return Lottie(
        composition: _composition,
        fit: BoxFit.contain,
      );
    }

    // Still loading
    if (_isLoading) {
      return _buildLoadingIndicator();
    }

    return _buildPlaceholder(context);
  }

  Widget _buildStaticSticker() {
    final path = _localPath;
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
          style: TextStyle(
            fontSize: widget.size > 40 ? 32 : 20,
          ),
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
