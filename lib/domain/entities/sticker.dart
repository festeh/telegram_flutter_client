/// Helper to parse int that might come as String (TDLib sends large IDs as strings)
int _parseIntOrString(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? defaultValue;
  return defaultValue;
}

/// Represents a single sticker from TDLib.
class Sticker {
  final int id;
  final int setId;
  final String emoji;
  final String? localPath;
  final int fileId;
  final int width;
  final int height;
  final bool isAnimated;
  final bool isVideo;

  const Sticker({
    required this.id,
    required this.setId,
    required this.emoji,
    this.localPath,
    required this.fileId,
    required this.width,
    required this.height,
    this.isAnimated = false,
    this.isVideo = false,
  });

  factory Sticker.fromJson(Map<String, dynamic> json, {int? setId}) {
    final stickerFile = json['sticker'] as Map<String, dynamic>?;
    final localPath = stickerFile?['local']?['path'] as String?;
    final fileId = _parseIntOrString(stickerFile?['id']);

    // Check format for animation type
    final format = json['format'] as Map<String, dynamic>?;
    final formatType = format?['@type'] as String? ?? '';
    final isAnimated = formatType == 'stickerFormatTgs';
    final isVideo = formatType == 'stickerFormatWebm';

    return Sticker(
      id: _parseIntOrString(json['id']),
      setId: setId ?? _parseIntOrString(json['set_id']),
      emoji: json['emoji'] as String? ?? '',
      localPath: (localPath?.isNotEmpty == true) ? localPath : null,
      fileId: fileId,
      width: _parseIntOrString(json['width'], 512),
      height: _parseIntOrString(json['height'], 512),
      isAnimated: isAnimated,
      isVideo: isVideo,
    );
  }

  Sticker copyWith({
    int? id,
    int? setId,
    String? emoji,
    String? localPath,
    int? fileId,
    int? width,
    int? height,
    bool? isAnimated,
    bool? isVideo,
  }) {
    return Sticker(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      emoji: emoji ?? this.emoji,
      localPath: localPath ?? this.localPath,
      fileId: fileId ?? this.fileId,
      width: width ?? this.width,
      height: height ?? this.height,
      isAnimated: isAnimated ?? this.isAnimated,
      isVideo: isVideo ?? this.isVideo,
    );
  }

  @override
  String toString() => 'Sticker(id: $id, emoji: $emoji, fileId: $fileId)';
}

/// Represents a sticker set from TDLib.
class StickerSet {
  final int id;
  final String title;
  final String name;
  final List<Sticker> stickers;
  final String? thumbnailPath;
  final int? thumbnailFileId;
  final bool isAnimated;
  final bool isVideo;

  const StickerSet({
    required this.id,
    required this.title,
    required this.name,
    this.stickers = const [],
    this.thumbnailPath,
    this.thumbnailFileId,
    this.isAnimated = false,
    this.isVideo = false,
  });

  factory StickerSet.fromJson(Map<String, dynamic> json) {
    // Parse stickers list
    final stickersJson = json['stickers'] as List<dynamic>? ?? [];
    final setId = _parseIntOrString(json['id']);
    final List<Sticker> stickers = [];
    for (final s in stickersJson) {
      try {
        final stickerMap = Map<String, dynamic>.from(s as Map);
        stickers.add(Sticker.fromJson(stickerMap, setId: setId));
      } catch (e) {
        // Skip invalid stickers but log for debugging
        assert(() {
          print('Failed to parse sticker in set $setId: $e');
          return true;
        }());
      }
    }

    // Parse thumbnail
    final thumbnail = json['thumbnail'] as Map<String, dynamic>?;
    final thumbnailFile = thumbnail?['file'] as Map<String, dynamic>?;
    final thumbnailPath = thumbnailFile?['local']?['path'] as String?;
    final thumbnailFileId = _parseIntOrString(thumbnailFile?['id']);

    // Check sticker type
    final stickerType = json['sticker_type'] as Map<String, dynamic>?;
    final typeStr = stickerType?['@type'] as String? ?? '';

    return StickerSet(
      id: setId,
      title: json['title'] as String? ?? '',
      name: json['name'] as String? ?? '',
      stickers: stickers,
      thumbnailPath: (thumbnailPath?.isNotEmpty == true) ? thumbnailPath : null,
      thumbnailFileId: thumbnailFileId > 0 ? thumbnailFileId : null,
      isAnimated: typeStr == 'stickerTypeCustomEmoji' ||
                  stickers.any((s) => s.isAnimated),
      isVideo: stickers.any((s) => s.isVideo),
    );
  }

  /// Creates a StickerSet with just basic info (from stickerSetInfo).
  factory StickerSet.fromInfoJson(Map<String, dynamic> json) {
    // Parse thumbnail
    final thumbnail = json['thumbnail'] as Map<String, dynamic>?;
    final thumbnailFile = thumbnail?['file'] as Map<String, dynamic>?;
    final thumbnailPath = thumbnailFile?['local']?['path'] as String?;
    final thumbnailFileId = _parseIntOrString(thumbnailFile?['id']);

    // Parse covers (first sticker as preview)
    final covers = json['covers'] as List<dynamic>? ?? [];
    final setId = _parseIntOrString(json['id']);
    final List<Sticker> coverStickers = [];
    for (final s in covers) {
      try {
        final stickerMap = Map<String, dynamic>.from(s as Map);
        coverStickers.add(Sticker.fromJson(stickerMap, setId: setId));
      } catch (e) {
        // Skip invalid cover stickers but log for debugging
        assert(() {
          print('Failed to parse cover sticker in set $setId: $e');
          return true;
        }());
      }
    }

    return StickerSet(
      id: setId,
      title: json['title'] as String? ?? '',
      name: json['name'] as String? ?? '',
      stickers: coverStickers, // Just covers initially
      thumbnailPath: (thumbnailPath?.isNotEmpty == true) ? thumbnailPath : null,
      thumbnailFileId: thumbnailFileId > 0 ? thumbnailFileId : null,
    );
  }

  StickerSet copyWith({
    int? id,
    String? title,
    String? name,
    List<Sticker>? stickers,
    String? thumbnailPath,
    int? thumbnailFileId,
    bool? isAnimated,
    bool? isVideo,
  }) {
    return StickerSet(
      id: id ?? this.id,
      title: title ?? this.title,
      name: name ?? this.name,
      stickers: stickers ?? this.stickers,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailFileId: thumbnailFileId ?? this.thumbnailFileId,
      isAnimated: isAnimated ?? this.isAnimated,
      isVideo: isVideo ?? this.isVideo,
    );
  }

  @override
  String toString() => 'StickerSet(id: $id, title: $title, stickers: ${stickers.length})';
}
