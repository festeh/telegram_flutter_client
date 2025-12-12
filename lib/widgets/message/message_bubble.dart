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
    super.key,
    required this.message,
    this.showTime = true,
    this.showSender = false,
    this.onLongPress,
    this.onTap,
  });

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
                _buildAvatar(context),
                const SizedBox(width: 8),
              ],
            Flexible(
              child: Column(
                crossAxisAlignment: message.isOutgoing
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (showSender && !message.isOutgoing)
                    _buildSenderName(context),
                  _buildMessageBubble(context),
                  if (showTime) _buildTimeStamp(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary,
      ),
      child: Center(
        child: Text(
          _getSenderInitial(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSenderName(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 12),
      child: Text(
        'User ${message.senderId}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOutgoing = message.isOutgoing;

    return Container(
      decoration: BoxDecoration(
        color: isOutgoing
            ? colorScheme.primary
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
          bottomRight: Radius.circular(isOutgoing ? 4 : 16),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: !isOutgoing ? Border.all(
          color: colorScheme.outline,
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
        return _buildTextMessage(context);
      case MessageType.photo:
        return _buildMediaMessage(context, Icons.photo, 'Photo');
      case MessageType.video:
        return _buildMediaMessage(context, Icons.videocam, 'Video');
      case MessageType.document:
        return _buildMediaMessage(context, Icons.description, 'Document');
      case MessageType.audio:
        return _buildMediaMessage(context, Icons.audiotrack, 'Audio');
      case MessageType.voice:
        return _buildMediaMessage(context, Icons.mic, 'Voice message');
      case MessageType.sticker:
        return _buildMediaMessage(context, Icons.emoji_emotions, 'Sticker');
      case MessageType.animation:
        return _buildMediaMessage(context, Icons.gif, 'GIF');
    }
  }

  Widget _buildTextMessage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SelectableText(
      message.content,
      style: TextStyle(
        fontSize: 16,
        height: 1.3,
        color: message.isOutgoing
            ? colorScheme.onPrimary
            : colorScheme.onSurface,
      ),
    );
  }

  Widget _buildMediaMessage(BuildContext context, IconData icon, String label) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: message.isOutgoing
              ? colorScheme.onPrimary
              : colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            height: 1.3,
            color: message.isOutgoing
                ? colorScheme.onPrimary
                : colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeStamp(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.date),
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          if (message.isOutgoing) ...[
            const SizedBox(width: 4),
            _buildMessageStatus(context),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageStatus(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Icon(
      Icons.done,
      size: 14,
      color: colorScheme.onSurface.withValues(alpha: 0.5),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDay == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else if (messageDay.isAfter(today.subtract(const Duration(days: 7)))) {
      return DateFormat('EEE HH:mm').format(dateTime);
    } else if (messageDay.year == today.year) {
      return DateFormat('MMM dd HH:mm').format(dateTime);
    } else {
      return DateFormat('MMM dd, yyyy HH:mm').format(dateTime);
    }
  }

  String _getSenderInitial() {
    return message.senderId.toString()[0];
  }
}
