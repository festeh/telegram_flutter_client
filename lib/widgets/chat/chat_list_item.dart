import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/entities/chat.dart';
import '../../core/theme/app_theme.dart';

class ChatListItem extends StatefulWidget {
  final Chat chat;
  final bool isSelected;
  final VoidCallback? onTap;

  const ChatListItem({
    super.key,
    required this.chat,
    this.isSelected = false,
    this.onTap,
  });

  @override
  State<ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<ChatListItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _getBackgroundColor(colorScheme),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.chat.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: widget.isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildTimestamp(colorScheme),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(child: _buildLastMessage(colorScheme)),
                          const SizedBox(width: 8),
                          _buildUnreadBadge(colorScheme),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(ColorScheme colorScheme) {
    if (widget.isSelected) {
      return colorScheme.primary;
    }
    if (_isHovered) {
      return colorScheme.surfaceContainerHigh;
    }
    return Colors.transparent;
  }

  Widget _buildAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getAvatarColor(),
        image: widget.chat.photoPath != null
            ? DecorationImage(
                image: _getImageProvider(widget.chat.photoPath!),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {},
              )
            : null,
      ),
      child: widget.chat.photoPath == null
          ? Center(
              child: Text(
                _getInitials(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }

  Color _getAvatarColor() {
    final colors = AppTheme.avatarColors;
    return colors[widget.chat.id.abs() % colors.length];
  }

  String _getInitials() {
    final title = widget.chat.title.trim();
    if (title.isEmpty) return '?';

    final words = title.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return title[0].toUpperCase();
  }

  Widget _buildTimestamp(ColorScheme colorScheme) {
    final lastActivity = widget.chat.lastActivity;
    if (lastActivity == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final diff = now.difference(lastActivity);

    String timeText;
    final timeColor = widget.isSelected
        ? colorScheme.onPrimary.withValues(alpha: 0.7)
        : colorScheme.onSurface.withValues(alpha: 0.5);

    if (diff.inDays > 0) {
      if (diff.inDays == 1) {
        timeText = 'yesterday';
      } else if (diff.inDays < 7) {
        timeText = '${diff.inDays}d ago';
      } else {
        timeText = '${(diff.inDays / 7).floor()}w ago';
      }
    } else if (diff.inHours > 0) {
      timeText = '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      timeText = '${diff.inMinutes}m ago';
    } else {
      timeText = 'now';
    }

    return Text(timeText, style: TextStyle(fontSize: 12, color: timeColor));
  }

  Widget _buildLastMessage(ColorScheme colorScheme) {
    final lastMessage = widget.chat.lastMessage;
    final textColor = widget.isSelected
        ? colorScheme.onPrimary.withValues(alpha: 0.7)
        : colorScheme.onSurface.withValues(alpha: 0.5);

    if (lastMessage == null) {
      return Text(
        'No messages yet',
        style: TextStyle(fontSize: 14, color: textColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    String messagePrefix = '';
    if (lastMessage.isOutgoing) {
      messagePrefix = 'You: ';
    }

    // Get display text - use content if available, otherwise show type placeholder
    final displayText = lastMessage.content.isNotEmpty
        ? lastMessage.content
        : _getMessageTypeLabel(lastMessage.type);

    return Text(
      '$messagePrefix$displayText',
      style: TextStyle(fontSize: 14, color: textColor),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _getMessageTypeLabel(MessageType type) {
    switch (type) {
      case MessageType.photo:
        return '📷 Photo';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.sticker:
        return '🎭 Sticker';
      case MessageType.document:
        return '📎 Document';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.voice:
        return '🎤 Voice message';
      case MessageType.animation:
        return '🎞️ GIF';
      case MessageType.text:
        return 'Message';
    }
  }

  Widget _buildUnreadBadge(ColorScheme colorScheme) {
    if (widget.chat.unreadCount <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.chat.isMuted
            ? colorScheme.secondary
            : colorScheme.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      child: Center(
        child: Text(
          widget.chat.unreadCount > 99 ? '99+' : '${widget.chat.unreadCount}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: widget.chat.isMuted
                ? colorScheme.onSecondary
                : colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
