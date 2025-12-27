enum ChatType { private, basicGroup, supergroup, secret, channel }

/// Media file info for photos
class PhotoInfo {
  final String? path;
  final int? fileId;
  final int? width;
  final int? height;

  const PhotoInfo({this.path, this.fileId, this.width, this.height});

  PhotoInfo copyWith({String? path, int? fileId, int? width, int? height}) {
    return PhotoInfo(
      path: path ?? this.path,
      fileId: fileId ?? this.fileId,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }
}

/// Media file info for stickers
class StickerInfo {
  final String? path;
  final int? fileId;
  final int? width;
  final int? height;
  final String? emoji;
  final bool isAnimated;

  const StickerInfo({
    this.path,
    this.fileId,
    this.width,
    this.height,
    this.emoji,
    this.isAnimated = false,
  });

  StickerInfo copyWith({
    String? path,
    int? fileId,
    int? width,
    int? height,
    String? emoji,
    bool? isAnimated,
  }) {
    return StickerInfo(
      path: path ?? this.path,
      fileId: fileId ?? this.fileId,
      width: width ?? this.width,
      height: height ?? this.height,
      emoji: emoji ?? this.emoji,
      isAnimated: isAnimated ?? this.isAnimated,
    );
  }
}

/// Media file info for videos
class VideoInfo {
  final String? path;
  final int? fileId;
  final int? width;
  final int? height;
  final int? duration; // seconds
  final String? thumbnailPath;
  final int? thumbnailFileId;

  const VideoInfo({
    this.path,
    this.fileId,
    this.width,
    this.height,
    this.duration,
    this.thumbnailPath,
    this.thumbnailFileId,
  });

  VideoInfo copyWith({
    String? path,
    int? fileId,
    int? width,
    int? height,
    int? duration,
    String? thumbnailPath,
    int? thumbnailFileId,
  }) {
    return VideoInfo(
      path: path ?? this.path,
      fileId: fileId ?? this.fileId,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      thumbnailFileId: thumbnailFileId ?? this.thumbnailFileId,
    );
  }
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
  final bool canSendMessages;

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
    this.canSendMessages = true,
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
      if (positions == null || positions.isEmpty) {
        return false; // Empty = not in main list yet
      }
      return positions.any((pos) {
        final list = pos['list'] as Map<String, dynamic>?;
        return list?['@type'] == 'chatListMain';
      });
    }

    // Check if user can send messages in this chat
    bool parseCanSendMessages(Map<String, dynamic>? permissions) {
      if (permissions == null) return true; // Private chats default to true
      return permissions['can_send_basic_messages'] as bool? ?? true;
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
              (json['last_message']['date'] as int) * 1000,
            )
          : null,
      isMuted:
          json['notification_settings']?['mute_for'] != null &&
          (json['notification_settings']['mute_for'] as int) > 0,
      totalCount: json['message_count'] as int? ?? 0,
      isInMainList: parseIsInMainList(json['positions'] as List<dynamic>?),
      canSendMessages: parseCanSendMessages(
        json['permissions'] as Map<String, dynamic>?,
      ),
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
      'can_send_messages': canSendMessages,
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
    bool? canSendMessages,
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
      canSendMessages: canSendMessages ?? this.canSendMessages,
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
  final MessageSendingState? sendingState;
  // Media info (grouped)
  final PhotoInfo? photo;
  final StickerInfo? sticker;
  final VideoInfo? video;
  // Link preview photo (for messages with t.me links)
  final PhotoInfo? linkPreviewPhoto;
  // Reactions
  final List<MessageReaction>? reactions;
  // Reply
  final int? replyToMessageId;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName,
    required this.date,
    required this.content,
    required this.isOutgoing,
    required this.type,
    this.sendingState,
    this.photo,
    this.sticker,
    this.video,
    this.linkPreviewPhoto,
    this.reactions,
    this.replyToMessageId,
  });

  factory Message.fromJson(
    Map<String, dynamic> json, {
    String? senderName,
    PhotoInfo? linkPreviewPhoto,
  }) {
    // Parse message content from TDLib format
    String parseContent(Map<String, dynamic>? contentMap) {
      if (contentMap == null) return '';

      final type = contentMap['@type'] as String;
      switch (type) {
        case 'messageText':
          return contentMap['text']?['text'] as String? ?? '';
        case 'messagePhoto':
          final caption = contentMap['caption']?['text'] as String?;
          return caption?.isNotEmpty == true ? caption! : '';
        case 'messageVideo':
          final caption = contentMap['caption']?['text'] as String?;
          return caption?.isNotEmpty == true ? caption! : '';
        case 'messageVideoNote':
          // Video notes don't have captions
          return '';
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
        case 'messageAnimatedEmoji':
          final emoji = contentMap['emoji'] as String?;
          return emoji ?? '[AnimatedEmoji: $contentMap]';
        case 'messageContact':
          return '👤 Contact';
        case 'messageLocation':
          return '📍 Location';
        case 'messagePoll':
          return '📊 Poll';
        case 'messageCall':
          return '📞 Call';
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
        case 'messageVideoNote':
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
    PhotoInfo? parsePhotoInfo(Map<String, dynamic>? contentMap) {
      if (contentMap == null || contentMap['@type'] != 'messagePhoto') {
        return null;
      }

      final photo = contentMap['photo'] as Map<String, dynamic>?;
      if (photo == null) return null;

      // Get the best size (prefer larger sizes for display)
      final sizes = photo['sizes'] as List?;
      if (sizes == null || sizes.isEmpty) return null;

      // Find the largest size (typically 'm' or 'x' type)
      Map<String, dynamic>? bestSize;
      int bestArea = 0;
      for (final size in sizes) {
        if (size is Map<String, dynamic>) {
          final w = size['width'] as int? ?? 0;
          final h = size['height'] as int? ?? 0;
          final area = w * h;
          if (area > bestArea) {
            bestArea = area;
            bestSize = size;
          }
        }
      }

      if (bestSize == null) return null;

      final fileInfo = bestSize['photo'] as Map<String, dynamic>?;
      final localPath = fileInfo?['local']?['path'] as String?;

      return PhotoInfo(
        path: (localPath?.isNotEmpty == true) ? localPath : null,
        fileId: fileInfo?['id'] as int?,
        width: bestSize['width'] as int?,
        height: bestSize['height'] as int?,
      );
    }

    final photo = parsePhotoInfo(json['content']);

    // Parse sticker info from messageSticker content
    StickerInfo? parseStickerInfo(Map<String, dynamic>? contentMap) {
      if (contentMap == null || contentMap['@type'] != 'messageSticker') {
        return null;
      }

      final stickerData = contentMap['sticker'] as Map<String, dynamic>?;
      if (stickerData == null) return null;

      // Get sticker file info - the file is in sticker['sticker']
      final stickerFile = stickerData['sticker'] as Map<String, dynamic>?;
      final localPath = stickerFile?['local']?['path'] as String?;

      // Check if animated (TGS format)
      final format = stickerData['format'] as Map<String, dynamic>?;

      return StickerInfo(
        path: (localPath?.isNotEmpty == true) ? localPath : null,
        fileId: stickerFile?['id'] as int?,
        width: stickerData['width'] as int?,
        height: stickerData['height'] as int?,
        emoji: stickerData['emoji'] as String?,
        isAnimated: format?['@type'] == 'stickerFormatTgs',
      );
    }

    final sticker = parseStickerInfo(json['content']);

    // Parse video info from messageVideo content
    VideoInfo? parseVideoInfo(Map<String, dynamic>? contentMap) {
      if (contentMap == null || contentMap['@type'] != 'messageVideo') {
        return null;
      }

      final videoData = contentMap['video'] as Map<String, dynamic>?;
      if (videoData == null) return null;

      // Get video file info
      final videoFile = videoData['video'] as Map<String, dynamic>?;
      final localPath = videoFile?['local']?['path'] as String?;

      // Get thumbnail info
      final thumbnail = videoData['thumbnail'] as Map<String, dynamic>?;
      final thumbnailFile = thumbnail?['file'] as Map<String, dynamic>?;
      final thumbnailPath = thumbnailFile?['local']?['path'] as String?;

      return VideoInfo(
        path: (localPath?.isNotEmpty == true) ? localPath : null,
        fileId: videoFile?['id'] as int?,
        width: videoData['width'] as int?,
        height: videoData['height'] as int?,
        duration: videoData['duration'] as int?,
        thumbnailPath: (thumbnailPath?.isNotEmpty == true)
            ? thumbnailPath
            : null,
        thumbnailFileId: thumbnailFile?['id'] as int?,
      );
    }

    final video = parseVideoInfo(json['content']);

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

    // Parse reactions from interaction_info
    List<MessageReaction>? parseReactions(
      Map<String, dynamic>? interactionInfo,
    ) {
      if (interactionInfo == null) return null;
      final reactionsData =
          interactionInfo['reactions'] as Map<String, dynamic>?;
      if (reactionsData == null) return null;
      final reactionsList = reactionsData['reactions'] as List<dynamic>?;
      if (reactionsList == null || reactionsList.isEmpty) return null;
      return reactionsList
          .whereType<Map<String, dynamic>>()
          .map((r) => MessageReaction.fromJson(r))
          .toList();
    }

    final reactions = parseReactions(
      json['interaction_info'] as Map<String, dynamic>?,
    );

    // Parse sending state from TDLib
    MessageSendingState? parseSendingState(
      Map<String, dynamic>? sendingStateMap,
    ) {
      if (sendingStateMap == null) {
        return MessageSendingState.sent; // No state = already sent
      }
      final type = sendingStateMap['@type'] as String?;
      switch (type) {
        case 'messageSendingStatePending':
          return MessageSendingState.pending;
        case 'messageSendingStateFailed':
          return MessageSendingState.failed;
        default:
          return MessageSendingState.sent;
      }
    }

    final sendingState = parseSendingState(
      json['sending_state'] as Map<String, dynamic>?,
    );

    // Parse reply_to for reply messages
    int? parseReplyToMessageId(Map<String, dynamic>? replyTo) {
      if (replyTo == null) return null;
      // TDLib 1.8+: reply_to contains message_id
      return replyTo['message_id'] as int?;
    }

    final replyToMessageId = parseReplyToMessageId(
      json['reply_to'] as Map<String, dynamic>?,
    );

    return Message(
      id: json['id'] as int,
      chatId: json['chat_id'] as int,
      senderId: parseSenderId(json['sender_id'] as Map<String, dynamic>?),
      senderName: senderName,
      date: DateTime.fromMillisecondsSinceEpoch((json['date'] as int) * 1000),
      content: parseContent(json['content']),
      isOutgoing: json['is_outgoing'] as bool? ?? false,
      type: parseMessageType(json['content']),
      sendingState: sendingState,
      photo: photo,
      sticker: sticker,
      video: video,
      linkPreviewPhoto: linkPreviewPhoto,
      reactions: reactions,
      replyToMessageId: replyToMessageId,
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
      'sending_state': sendingState?.name,
      if (photo != null)
        'photo': {
          'path': photo!.path,
          'file_id': photo!.fileId,
          'width': photo!.width,
          'height': photo!.height,
        },
      if (sticker != null)
        'sticker': {
          'path': sticker!.path,
          'file_id': sticker!.fileId,
          'width': sticker!.width,
          'height': sticker!.height,
          'emoji': sticker!.emoji,
          'is_animated': sticker!.isAnimated,
        },
      if (video != null)
        'video': {
          'path': video!.path,
          'file_id': video!.fileId,
          'width': video!.width,
          'height': video!.height,
          'duration': video!.duration,
          'thumbnail_path': video!.thumbnailPath,
          'thumbnail_file_id': video!.thumbnailFileId,
        },
      'reactions': reactions
          ?.map(
            (r) => {
              'type': r.type.name,
              'emoji': r.emoji,
              'custom_emoji_id': r.customEmojiId,
              'count': r.count,
              'is_chosen': r.isChosen,
            },
          )
          .toList(),
      'reply_to_message_id': replyToMessageId,
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
    MessageSendingState? sendingState,
    PhotoInfo? photo,
    StickerInfo? sticker,
    VideoInfo? video,
    PhotoInfo? linkPreviewPhoto,
    List<MessageReaction>? reactions,
    int? replyToMessageId,
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
      sendingState: sendingState ?? this.sendingState,
      photo: photo ?? this.photo,
      sticker: sticker ?? this.sticker,
      video: video ?? this.video,
      linkPreviewPhoto: linkPreviewPhoto ?? this.linkPreviewPhoto,
      reactions: reactions ?? this.reactions,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
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

enum MessageSendingState {
  pending, // Optimistic local message, not yet sent to server
  sent, // Server confirmed receipt
  read, // Recipient has read
  failed, // Send failed
}

enum ReactionType { emoji, customEmoji, paid }

class MessageReaction {
  final ReactionType type;
  final String? emoji;
  final int? customEmojiId;
  final int? customEmojiFileId;
  final String? customEmojiPath;
  final int count;
  final bool isChosen;

  const MessageReaction({
    required this.type,
    this.emoji,
    this.customEmojiId,
    this.customEmojiFileId,
    this.customEmojiPath,
    required this.count,
    required this.isChosen,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    final reactionType = json['type'] as Map<String, dynamic>;
    final typeString = reactionType['@type'] as String;

    if (typeString == 'reactionTypeCustomEmoji') {
      return MessageReaction(
        type: ReactionType.customEmoji,
        customEmojiId: reactionType['custom_emoji_id'] as int?,
        count: json['total_count'] as int? ?? 0,
        isChosen: json['is_chosen'] as bool? ?? false,
      );
    } else if (typeString == 'reactionTypePaid') {
      return MessageReaction(
        type: ReactionType.paid,
        emoji: '⭐', // Use star as display for paid reactions
        count: json['total_count'] as int? ?? 0,
        isChosen: json['is_chosen'] as bool? ?? false,
      );
    } else {
      return MessageReaction(
        type: ReactionType.emoji,
        emoji: reactionType['emoji'] as String?,
        count: json['total_count'] as int? ?? 0,
        isChosen: json['is_chosen'] as bool? ?? false,
      );
    }
  }

  MessageReaction copyWith({
    ReactionType? type,
    String? emoji,
    int? customEmojiId,
    int? customEmojiFileId,
    String? customEmojiPath,
    int? count,
    bool? isChosen,
  }) {
    return MessageReaction(
      type: type ?? this.type,
      emoji: emoji ?? this.emoji,
      customEmojiId: customEmojiId ?? this.customEmojiId,
      customEmojiFileId: customEmojiFileId ?? this.customEmojiFileId,
      customEmojiPath: customEmojiPath ?? this.customEmojiPath,
      count: count ?? this.count,
      isChosen: isChosen ?? this.isChosen,
    );
  }

  @override
  String toString() {
    return 'MessageReaction(type: $type, emoji: $emoji, customEmojiId: $customEmojiId, count: $count, isChosen: $isChosen)';
  }
}
