import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/chat.dart';

class MessageBubble extends ConsumerWidget {
  final Message message;
  final bool showTime;
  final bool showSender;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;

  const MessageBubble({
    Key? key,
    required this.message,
    this.showTime = true,
    this.showSender = false,
    this.onLongPress,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(
          left: message.isOutgoing ? 50 : 10,
          right: message.isOutgoing ? 10 : 50,
          top: 4,
          bottom: 4,
        ),
        child: Row(
          mainAxisAlignment: message.isOutgoing 
              ? MainAxisAlignment.end 
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!message.isOutgoing) 
              ...[
                _buildAvatar(),
                const SizedBox(width: 8),
              ],
            Flexible(
              child: Column(
                crossAxisAlignment: message.isOutgoing 
                    ? CrossAxisAlignment.end 
                    : CrossAxisAlignment.start,
                children: [
                  if (showSender && !message.isOutgoing)
                    _buildSenderName(),
                  _buildMessageBubble(context),
                  if (showTime) _buildTimeStamp(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF3390EC),
      ),
      child: Center(
        child: Text(
          _getSenderInitial(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildSenderName() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 12),
      child: Text(
        'User ${message.senderId}', // Placeholder - would need user info
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF3390EC),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: message.isOutgoing 
            ? const Color(0xFF3390EC)
            : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(message.isOutgoing ? 16 : 4),
          bottomRight: Radius.circular(message.isOutgoing ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: !message.isOutgoing ? Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: _buildMessageContent(context),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return _buildTextMessage();
      case MessageType.photo:
        return _buildMediaMessage(Icons.photo, 'Photo');
      case MessageType.video:
        return _buildMediaMessage(Icons.videocam, 'Video');
      case MessageType.document:
        return _buildMediaMessage(Icons.description, 'Document');
      case MessageType.audio:
        return _buildMediaMessage(Icons.audiotrack, 'Audio');
      case MessageType.voice:
        return _buildMediaMessage(Icons.mic, 'Voice message');
      case MessageType.sticker:
        return _buildMediaMessage(Icons.emoji_emotions, 'Sticker');
      case MessageType.animation:
        return _buildMediaMessage(Icons.gif, 'GIF');
      default:
        return _buildTextMessage();
    }
  }

  Widget _buildTextMessage() {
    return SelectableText(
      message.content,
      style: TextStyle(
        fontSize: 16,
        height: 1.3,
        color: message.isOutgoing 
            ? Colors.white 
            : const Color(0xFF111827),
      ),
    );
  }

  Widget _buildMediaMessage(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: message.isOutgoing 
              ? Colors.white 
              : const Color(0xFF6B7280),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            height: 1.3,
            color: message.isOutgoing 
                ? Colors.white 
                : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeStamp() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.date),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
            ),
          ),
          if (message.isOutgoing) ...[
            const SizedBox(width: 4),
            _buildMessageStatus(),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageStatus() {
    // For now, show a simple checkmark
    // In a full implementation, this would show different states:
    // - Clock: sending
    // - Single check: sent
    // - Double check: delivered
    // - Double check blue: read
    return const Icon(
      Icons.done,
      size: 14,
      color: Color(0xFF9CA3AF),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDay == today) {
      // Today - show only time
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else if (messageDay.isAfter(today.subtract(const Duration(days: 7)))) {
      // This week - show day name
      return DateFormat('EEE HH:mm').format(dateTime);
    } else if (messageDay.year == today.year) {
      // This year - show month and day
      return DateFormat('MMM dd HH:mm').format(dateTime);
    } else {
      // Different year - show full date
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    }
  }

  String _getSenderInitial() {
    // Placeholder - would get from actual user data
    return message.senderId.toString()[0];
  }
}