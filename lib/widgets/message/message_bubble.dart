import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/chat.dart';
import '../../core/theme/app_theme.dart';
import '../../presentation/providers/telegram_client_provider.dart';
import 'photo_message.dart';
import 'sticker_message.dart';

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
            Flexible(
              child: Column(
                crossAxisAlignment: message.isOutgoing
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (showSender && !message.isOutgoing)
                    _buildSenderName(context),
                  if (message.type == MessageType.sticker)
                    _buildStickerMessage(context)
                  else
                    _buildMessageBubble(context),
                  if (showTime) _buildTimeStamp(context),
                  if (message.reactions != null && message.reactions!.isNotEmpty)
                    _buildReactionsRow(context, ref),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor() {
    return AppTheme.avatarColors[message.senderId.abs() % AppTheme.avatarColors.length];
  }

  Widget _buildSenderName(BuildContext context) {
    final avatarColor = _getAvatarColor();
    final displayName = message.senderName ?? 'User ${message.senderId}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 12),
      child: Text(
        displayName,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: avatarColor,
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
        return _buildPhotoMessage(context);
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

  Widget _buildPhotoMessage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCaption = message.content.isNotEmpty && message.content != '📷 Photo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhotoMessageWidget(
          photoPath: message.photoPath,
          photoWidth: message.photoWidth,
          photoHeight: message.photoHeight,
          isOutgoing: message.isOutgoing,
        ),
        if (hasCaption) ...[
          const SizedBox(height: 8),
          Text(
            message.content,
            style: TextStyle(
              fontSize: 16,
              height: 1.3,
              color: message.isOutgoing
                  ? colorScheme.onPrimary
                  : colorScheme.onSurface,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStickerMessage(BuildContext context) {
    return StickerMessageWidget(
      stickerPath: message.stickerPath,
      stickerWidth: message.stickerWidth,
      stickerHeight: message.stickerHeight,
      isAnimated: message.stickerIsAnimated,
      emoji: message.stickerEmoji,
    );
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
    final mutedColor = colorScheme.onSurface.withValues(alpha: 0.5);

    switch (message.sendingState) {
      case MessageSendingState.pending:
        return Icon(Icons.access_time, size: 14, color: mutedColor);
      case MessageSendingState.sent:
        return Icon(Icons.done, size: 14, color: mutedColor);
      case MessageSendingState.read:
        return Icon(Icons.done_all, size: 14, color: colorScheme.primary);
      case MessageSendingState.failed:
        return Icon(Icons.error_outline, size: 14, color: colorScheme.error);
      case null:
        // Default for messages loaded from history (already sent)
        return Icon(Icons.done, size: 14, color: mutedColor);
    }
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

  Widget _buildReactionsRow(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final reactions = message.reactions!;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: reactions.map((reaction) {
          final isChosen = reaction.isChosen;
          final isPaid = reaction.type == ReactionType.paid;
          return GestureDetector(
            onTap: isPaid ? null : () => _toggleReaction(ref, reaction),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isChosen
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isChosen
                      ? colorScheme.primary
                      : colorScheme.outline.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if ((reaction.type == ReactionType.emoji || reaction.type == ReactionType.paid) && reaction.emoji != null)
                    Text(
                      reaction.emoji!,
                      style: const TextStyle(fontSize: 14),
                    )
                  else if (reaction.type == ReactionType.customEmoji && reaction.customEmojiPath != null)
                    // Custom emoji with downloaded image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.file(
                        File(reaction.customEmojiPath!),
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.emoji_emotions,
                          size: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    )
                  else if (reaction.type == ReactionType.customEmoji)
                    // Custom emoji loading placeholder
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    )
                  else
                    // Fallback for unknown reaction types
                    Icon(
                      Icons.emoji_emotions,
                      size: 14,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  const SizedBox(width: 4),
                  Text(
                    '${reaction.count}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isChosen ? FontWeight.w600 : FontWeight.w400,
                      color: isChosen
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _toggleReaction(WidgetRef ref, MessageReaction reaction) {
    final client = ref.read(telegramClientProvider);
    if (reaction.isChosen) {
      client.removeReaction(message.chatId, message.id, reaction);
    } else {
      client.addReaction(message.chatId, message.id, reaction);
    }
  }
}
