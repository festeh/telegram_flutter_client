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
  final DateTime date;
  final String content;
  final bool isOutgoing;
  final MessageType type;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.date,
    required this.content,
    required this.isOutgoing,
    required this.type,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Parse message content from TDLib format
    String parseContent(Map<String, dynamic>? contentMap) {
      if (contentMap == null) return '';

      final type = contentMap['@type'] as String;
      switch (type) {
        case 'messageText':
          return contentMap['text']?['text'] as String? ?? '';
        case 'messagePhoto':
          return '📷 Photo';
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

    return Message(
      id: json['id'] as int,
      chatId: json['chat_id'] as int,
      senderId: json['sender_id']?['user_id'] as int? ?? 0,
      date: DateTime.fromMillisecondsSinceEpoch(
        (json['date'] as int) * 1000,
      ),
      content: parseContent(json['content']),
      isOutgoing: json['is_outgoing'] as bool? ?? false,
      type: parseMessageType(json['content']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'date': date.millisecondsSinceEpoch ~/ 1000,
      'content': content,
      'is_outgoing': isOutgoing,
      'type': type.toString().split('.').last,
    };
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
