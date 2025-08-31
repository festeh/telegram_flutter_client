import 'dart:io';
import 'package:flutter/material.dart';
import '../../domain/entities/chat.dart';

class ChatListItem extends StatefulWidget {
  final Chat chat;
  final bool isSelected;
  final VoidCallback? onTap;

  const ChatListItem({
    Key? key,
    required this.chat,
    this.isSelected = false,
    this.onTap,
  }) : super(key: key);

  @override
  State<ChatListItem> createState() => _ChatListItemState();
}

class _ChatListItemState extends State<ChatListItem>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar
                _buildAvatar(),
                const SizedBox(width: 12),
                // Chat info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and timestamp row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.chat.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF000000),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildTimestamp(),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // Last message and unread count row
                      Row(
                        children: [
                          Expanded(
                            child: _buildLastMessage(),
                          ),
                          const SizedBox(width: 8),
                          _buildUnreadBadge(),
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

  Color _getBackgroundColor() {
    if (widget.isSelected) {
      return const Color(0xFF3390EC); // Telegram blue for selected
    }
    if (_isHovered) {
      return const Color(0xFFF1F1F1); // Light gray for hover
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
                onError: (exception, stackTrace) {
                  // Handle image loading error silently, fallback to initials
                },
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
    // Check if the path is a network URL
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    // Otherwise, treat it as a local file path
    return FileImage(File(path));
  }

  Color _getAvatarColor() {
    // Generate a color based on the chat ID for consistency
    final colors = [
      const Color(0xFFE57373), // Red
      const Color(0xFF81C784), // Green
      const Color(0xFF64B5F6), // Blue
      const Color(0xFFFFB74D), // Orange
      const Color(0xFFBA68C8), // Purple
      const Color(0xFF4DB6AC), // Teal
      const Color(0xFFF06292), // Pink
      const Color(0xFF9575CD), // Deep purple
    ];
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

  Widget _buildTimestamp() {
    final lastActivity = widget.chat.lastActivity;
    if (lastActivity == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final diff = now.difference(lastActivity);

    String timeText;
    Color timeColor =
        widget.isSelected ? Colors.white70 : const Color(0xFF8E8E93);

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

    return Text(
      timeText,
      style: TextStyle(
        fontSize: 12,
        color: timeColor,
      ),
    );
  }

  Widget _buildLastMessage() {
    final lastMessage = widget.chat.lastMessage;
    if (lastMessage == null) {
      return Text(
        'No messages yet',
        style: TextStyle(
          fontSize: 14,
          color: widget.isSelected ? Colors.white70 : const Color(0xFF8E8E93),
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    String messagePrefix = '';
    if (lastMessage.isOutgoing) {
      messagePrefix = 'You: ';
    }

    return Text(
      '$messagePrefix${lastMessage.content}',
      style: TextStyle(
        fontSize: 14,
        color: widget.isSelected ? Colors.white70 : const Color(0xFF8E8E93),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildUnreadBadge() {
    if (widget.chat.unreadCount <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: widget.chat.isMuted
            ? const Color(0xFF8E8E93)
            : const Color(0xFF3390EC),
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
      child: Center(
        child: Text(
          widget.chat.unreadCount > 99 ? '99+' : '${widget.chat.unreadCount}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
