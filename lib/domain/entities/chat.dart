enum ChatType {
  private,
  basicGroup,
  supergroup,
  secret,
  channel,
}

class Chat {
  final int id;
  final String title;
  final ChatType type;
  final String? photoPath;
  final int? photoFileId;
  final Message? lastMessage;
  final int unreadCount;
  final bool isPinned;
  final DateTime? lastActivity;
  final bool isMuted;
  final int totalCount;
  final bool isInMainList;

  const Chat({
    required this.id,
    required this.title,
    required this.type,
    this.photoPath,
    this.photoFileId,
    this.lastMessage,
    this.unreadCount = 0,
    this.isPinned = false,
    this.lastActivity,
    this.isMuted = false,
    this.totalCount = 0,
    this.isInMainList = true,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    // Parse chat type from TDLib format
    ChatType parseChatType(Map<String, dynamic> typeMap) {
      final type = typeMap['@type'] as String;
      switch (type) {
        case 'chatTypePrivate':
          return ChatType.private;
        case 'chatTypeBasicGroup':
          return ChatType.basicGroup;
        case 'chatTypeSupergroup':
          return typeMap['is_channel'] == true
              ? ChatType.channel
              : ChatType.supergroup;
        case 'chatTypeSecret':
          return ChatType.secret;
        default:
          return ChatType.private;
      }
    }

    // Parse last message if available
    Message? parseLastMessage(Map<String, dynamic>? messageMap) {
      if (messageMap == null) return null;
      return Message.fromJson(messageMap);
    }

    // Parse photo path
    String? parsePhotoPath(Map<String, dynamic>? photoMap) {
      if (photoMap == null) return null;
      final small = photoMap['small'] as Map<String, dynamic>?;
      if (small == null) return null;
      final path = small['local']?['path'] as String?;
      // Return null for empty paths (file not downloaded yet)
      return (path != null && path.isNotEmpty) ? path : null;
    }

    // Parse photo file ID for download
    int? parsePhotoFileId(Map<String, dynamic>? photoMap) {
      if (photoMap == null) return null;
      final small = photoMap['small'] as Map<String, dynamic>?;
      return small?['id'] as int?;
    }

    // Check if chat has position in main list
    bool parseIsInMainList(List<dynamic>? positions) {
      if (positions == null || positions.isEmpty) return false; // Empty = not in main list yet
      return positions.any((pos) {
        final list = pos['list'] as Map<String, dynamic>?;
        return list?['@type'] == 'chatListMain';
      });
    }

    return Chat(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      type: parseChatType(json['type'] as Map<String, dynamic>),
      photoPath: parsePhotoPath(json['photo']),
      photoFileId: parsePhotoFileId(json['photo']),
      lastMessage: parseLastMessage(json['last_message']),
      unreadCount: json['unread_count'] as int? ?? 0,
      isPinned: json['is_pinned'] as bool? ?? false,
      lastActivity: json['last_message']?['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (json['last_message']['date'] as int) * 1000)
          : null,
      isMuted: json['notification_settings']?['mute_for'] != null &&
          (json['notification_settings']['mute_for'] as int) > 0,
      totalCount: json['message_count'] as int? ?? 0,
      isInMainList: parseIsInMainList(json['positions'] as List<dynamic>?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'type': type.toString().split('.').last,
      'photo_path': photoPath,
      'photo_file_id': photoFileId,
      'last_message': lastMessage?.toJson(),
      'unread_count': unreadCount,
      'is_pinned': isPinned,
      'last_activity': lastActivity?.millisecondsSinceEpoch,
      'is_muted': isMuted,
      'total_count': totalCount,
      'is_in_main_list': isInMainList,
    };
  }

  Chat copyWith({
    int? id,
    String? title,
    ChatType? type,
    String? photoPath,
    int? photoFileId,
    Message? lastMessage,
    int? unreadCount,
    bool? isPinned,
    DateTime? lastActivity,
    bool? isMuted,
    int? totalCount,
    bool? isInMainList,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      photoPath: photoPath ?? this.photoPath,
      photoFileId: photoFileId ?? this.photoFileId,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      lastActivity: lastActivity ?? this.lastActivity,
      isMuted: isMuted ?? this.isMuted,
      totalCount: totalCount ?? this.totalCount,
      isInMainList: isInMainList ?? this.isInMainList,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Chat && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Chat(id: $id, title: $title, type: $type, unreadCount: $unreadCount)';
  }
}

class Message {
  final int id;
  final int chatId;
  final int senderId;
  final String? senderName;
  final DateTime date;
  final String content;
  final bool isOutgoing;
  final MessageType type;
  // Photo-specific fields
  final String? photoPath;
  final int? photoFileId;
  final int? photoWidth;
  final int? photoHeight;
  // Sticker-specific fields
  final String? stickerPath;
  final int? stickerFileId;
  final int? stickerWidth;
  final int? stickerHeight;
  final String? stickerEmoji;
  final bool stickerIsAnimated;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    required this.date,
    required this.content,
    required this.isOutgoing,
    required this.type,
    this.photoPath,
    this.photoFileId,
    this.photoWidth,
    this.photoHeight,
    this.stickerPath,
    this.stickerFileId,
    this.stickerWidth,
    this.stickerHeight,
    this.stickerEmoji,
    this.stickerIsAnimated = false,
  });

  factory Message.fromJson(Map<String, dynamic> json, {String? senderName}) {
    // Parse message content from TDLib format
    String parseContent(Map<String, dynamic>? contentMap) {
      if (contentMap == null) return '';

      final type = contentMap['@type'] as String;
      switch (type) {
        case 'messageText':
          return contentMap['text']?['text'] as String? ?? '';
        case 'messagePhoto':
          // Include caption if available
          final caption = contentMap['caption']?['text'] as String?;
          return caption?.isNotEmpty == true ? caption! : '📷 Photo';
        case 'messageVideo':
          return '🎥 Video';
        case 'messageDocument':
          return '📎 Document';
        case 'messageAudio':
          return '🎵 Audio';
        case 'messageVoiceNote':
          return '🎤 Voice message';
        case 'messageSticker':
          return '🎭 Sticker';
        case 'messageAnimation':
          return '🎞️ GIF';
        default:
          return 'Message';
      }
    }

    MessageType parseMessageType(Map<String, dynamic>? contentMap) {
      if (contentMap == null) return MessageType.text;

      final type = contentMap['@type'] as String;
      switch (type) {
        case 'messageText':
          return MessageType.text;
        case 'messagePhoto':
          return MessageType.photo;
        case 'messageVideo':
          return MessageType.video;
        case 'messageDocument':
          return MessageType.document;
        case 'messageAudio':
          return MessageType.audio;
        case 'messageVoiceNote':
          return MessageType.voice;
        case 'messageSticker':
          return MessageType.sticker;
        case 'messageAnimation':
          return MessageType.animation;
        default:
          return MessageType.text;
      }
    }

    // Parse photo info from messagePhoto content
    ({String? path, int? fileId, int? width, int? height}) parsePhotoInfo(
        Map<String, dynamic>? contentMap) {
      if (contentMap == null || contentMap['@type'] != 'messagePhoto') {
        return (path: null, fileId: null, width: null, height: null);
      }

      final photo = contentMap['photo'] as Map<String, dynamic>?;
      if (photo == null) {
        return (path: null, fileId: null, width: null, height: null);
      }

      // Get the best size (prefer larger sizes for display)
      final sizes = photo['sizes'] as List?;
      if (sizes == null || sizes.isEmpty) {
        return (path: null, fileId: null, width: null, height: null);
      }

      // Find the largest size (typically 'm' or 'x' type)
      Map<String, dynamic>? bestSize;
      int bestArea = 0;
      for (final size in sizes) {
        if (size is Map<String, dynamic>) {
          final width = size['width'] as int? ?? 0;
          final height = size['height'] as int? ?? 0;
          final area = width * height;
          if (area > bestArea) {
            bestArea = area;
            bestSize = size;
          }
        }
      }

      if (bestSize == null) {
        return (path: null, fileId: null, width: null, height: null);
      }

      final fileInfo = bestSize['photo'] as Map<String, dynamic>?;
      final localPath = fileInfo?['local']?['path'] as String?;
      final fileId = fileInfo?['id'] as int?;
      final width = bestSize['width'] as int?;
      final height = bestSize['height'] as int?;

      return (
        path: (localPath?.isNotEmpty == true) ? localPath : null,
        fileId: fileId,
        width: width,
        height: height,
      );
    }

    final photoInfo = parsePhotoInfo(json['content']);

    // Parse sticker info from messageSticker content
    ({String? path, int? fileId, int? width, int? height, String? emoji, bool isAnimated}) parseStickerInfo(
        Map<String, dynamic>? contentMap) {
      if (contentMap == null || contentMap['@type'] != 'messageSticker') {
        return (path: null, fileId: null, width: null, height: null, emoji: null, isAnimated: false);
      }

      final sticker = contentMap['sticker'] as Map<String, dynamic>?;
      if (sticker == null) {
        return (path: null, fileId: null, width: null, height: null, emoji: null, isAnimated: false);
      }

      // Get sticker file info - the file is in sticker['sticker']
      final stickerFile = sticker['sticker'] as Map<String, dynamic>?;
      final localPath = stickerFile?['local']?['path'] as String?;
      final fileId = stickerFile?['id'] as int?;

      // Get dimensions and emoji
      final width = sticker['width'] as int?;
      final height = sticker['height'] as int?;
      final emoji = sticker['emoji'] as String?;

      // Check if animated (TGS format)
      final format = sticker['format'] as Map<String, dynamic>?;
      final isAnimated = format?['@type'] == 'stickerFormatTgs';

      return (
        path: (localPath?.isNotEmpty == true) ? localPath : null,
        fileId: fileId,
        width: width,
        height: height,
        emoji: emoji,
        isAnimated: isAnimated,
      );
    }

    final stickerInfo = parseStickerInfo(json['content']);

    // Parse sender ID - can be messageSenderUser or messageSenderChat
    int parseSenderId(Map<String, dynamic>? senderIdMap) {
      if (senderIdMap == null) return 0;
      // Check for user_id first (messageSenderUser)
      final userId = senderIdMap['user_id'] as int?;
      if (userId != null) return userId;
      // Fall back to chat_id (messageSenderChat)
      final chatId = senderIdMap['chat_id'] as int?;
      return chatId ?? 0;
    }

    return Message(
      id: json['id'] as int,
      chatId: json['chat_id'] as int,
      senderId: parseSenderId(json['sender_id'] as Map<String, dynamic>?),
      senderName: senderName,
      date: DateTime.fromMillisecondsSinceEpoch(
        (json['date'] as int) * 1000,
      ),
      content: parseContent(json['content']),
      isOutgoing: json['is_outgoing'] as bool? ?? false,
      type: parseMessageType(json['content']),
      photoPath: photoInfo.path,
      photoFileId: photoInfo.fileId,
      photoWidth: photoInfo.width,
      photoHeight: photoInfo.height,
      stickerPath: stickerInfo.path,
      stickerFileId: stickerInfo.fileId,
      stickerWidth: stickerInfo.width,
      stickerHeight: stickerInfo.height,
      stickerEmoji: stickerInfo.emoji,
      stickerIsAnimated: stickerInfo.isAnimated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'sender_name': senderName,
      'date': date.millisecondsSinceEpoch ~/ 1000,
      'content': content,
      'is_outgoing': isOutgoing,
      'type': type.toString().split('.').last,
      'photo_path': photoPath,
      'photo_file_id': photoFileId,
      'photo_width': photoWidth,
      'photo_height': photoHeight,
      'sticker_path': stickerPath,
      'sticker_file_id': stickerFileId,
      'sticker_width': stickerWidth,
      'sticker_height': stickerHeight,
      'sticker_emoji': stickerEmoji,
      'sticker_is_animated': stickerIsAnimated,
    };
  }

  Message copyWith({
    int? id,
    int? chatId,
    int? senderId,
    String? senderName,
    DateTime? date,
    String? content,
    bool? isOutgoing,
    MessageType? type,
    String? photoPath,
    int? photoFileId,
    int? photoWidth,
    int? photoHeight,
    String? stickerPath,
    int? stickerFileId,
    int? stickerWidth,
    int? stickerHeight,
    String? stickerEmoji,
    bool? stickerIsAnimated,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      date: date ?? this.date,
      content: content ?? this.content,
      isOutgoing: isOutgoing ?? this.isOutgoing,
      type: type ?? this.type,
      photoPath: photoPath ?? this.photoPath,
      photoFileId: photoFileId ?? this.photoFileId,
      photoWidth: photoWidth ?? this.photoWidth,
      photoHeight: photoHeight ?? this.photoHeight,
      stickerPath: stickerPath ?? this.stickerPath,
      stickerFileId: stickerFileId ?? this.stickerFileId,
      stickerWidth: stickerWidth ?? this.stickerWidth,
      stickerHeight: stickerHeight ?? this.stickerHeight,
      stickerEmoji: stickerEmoji ?? this.stickerEmoji,
      stickerIsAnimated: stickerIsAnimated ?? this.stickerIsAnimated,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, chatId: $chatId, content: $content)';
  }
}

enum MessageType {
  text,
  photo,
  video,
  document,
  audio,
  voice,
  sticker,
  animation,
}
