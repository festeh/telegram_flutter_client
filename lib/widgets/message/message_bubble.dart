import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/chat.dart';
import '../../core/theme/app_theme.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/providers/telegram_client_provider.dart';
import 'photo_message.dart';
import 'sticker_message.dart';
import 'video_message.dart';

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
                    _buildMessageBubble(context, ref),
                  if (showTime) _buildTimeStamp(context),
                  if (message.reactions != null &&
                      message.reactions!.isNotEmpty)
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
    return AppTheme.avatarColors[message.senderId.abs() %
        AppTheme.avatarColors.length];
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

  Widget _buildMessageBubble(BuildContext context, WidgetRef ref) {
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
        border: !isOutgoing
            ? Border.all(color: colorScheme.outline, width: 1)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.replyToMessageId != null)
              _buildReplyPreview(context, ref),
            _buildMessageContent(context),
          ],
        ),
      ),
    );
  }

  /// Get clean preview content for reply - strips URLs and handles media types
  String _getReplyPreviewContent(Message? message) {
    if (message == null) return 'Loading...';

    // For media types, show descriptive text
    switch (message.type) {
      case MessageType.photo:
        final caption = message.content;
        return caption.isNotEmpty ? '📷 $caption' : '📷 Photo';
      case MessageType.video:
        final caption = message.content;
        return caption.isNotEmpty ? '🎥 $caption' : '🎥 Video';
      case MessageType.sticker:
        return message.sticker?.emoji ?? '🎭 Sticker';
      case MessageType.document:
        return '📎 Document';
      case MessageType.audio:
        return '🎵 Audio';
      case MessageType.voice:
        return '🎤 Voice message';
      case MessageType.animation:
        return 'GIF';
      case MessageType.text:
        // Strip URLs from text for cleaner preview
        final text = message.content;
        if (text.isEmpty) return 'Message';
        // Remove URLs (http/https/t.me links)
        final cleanText = text
            .replaceAll(RegExp(r'https?://\S+'), '')
            .replaceAll(RegExp(r't\.me/\S+'), '')
            .trim();
        return cleanText.isNotEmpty ? cleanText : text;
    }
  }

  Widget _buildReplyPreview(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isOutgoing = message.isOutgoing;
    final replyToId = message.replyToMessageId;
    if (replyToId == null) return const SizedBox.shrink();

    // Watch reply cache version to rebuild when replies are fetched
    ref.watch(replyCacheVersionProvider);

    // Look up the original message from state (don't watch full provider to avoid rebuilds)
    final messageState = ref.read(messageProvider).value;
    final messages = messageState?.messagesByChat[message.chatId] ?? [];
    Message? repliedMessage = messages.cast<Message?>().firstWhere(
      (m) => m?.id == replyToId,
      orElse: () => null,
    );

    // If not in state, check TDLib client cache
    final client = ref.read(telegramClientProvider);
    repliedMessage ??= client.getCachedReplyMessage(message.chatId, replyToId);

    // If still not found, trigger async fetch (will rebuild when cached)
    if (repliedMessage == null) {
      // Pass both current message ID and replyToMessageId for proper TDLib getRepliedMessage API
      client.fetchReplyMessage(message.chatId, message.id, replyToId).then((
        msg,
      ) {
        if (msg != null) {
          // Bump version to trigger rebuild of bubbles with replies
          ref.read(replyCacheVersionProvider.notifier).bump();
        }
      });
    }

    final senderName =
        repliedMessage?.senderName ??
        (repliedMessage?.isOutgoing == true ? 'You' : 'User');
    final content = _getReplyPreviewContent(repliedMessage);
    final truncatedContent = content.length > 50
        ? '${content.substring(0, 50)}...'
        : content;

    final primaryColor = isOutgoing
        ? colorScheme.onPrimary.withValues(alpha: 0.8)
        : colorScheme.primary;
    final textColor = isOutgoing
        ? colorScheme.onPrimary.withValues(alpha: 0.7)
        : colorScheme.onSurface.withValues(alpha: 0.7);

    // Check if replied message has a photo (regular or link preview)
    final photoPath = repliedMessage?.photo?.path;
    final linkPreviewPhotoPath = repliedMessage?.linkPreviewPhoto?.path;
    final displayPhotoPath = photoPath ?? linkPreviewPhotoPath;
    final hasPhoto = displayPhotoPath != null && displayPhotoPath.isNotEmpty;

    // Check if photo is loading (has fileId but no path)
    final isPhotoLoading =
        repliedMessage != null &&
        !hasPhoto &&
        ((repliedMessage.photo?.fileId != null) ||
            (repliedMessage.linkPreviewPhoto?.fileId != null));

    // Capture for closure
    final replyMsg = repliedMessage;

    return GestureDetector(
      onTap: replyMsg != null
          ? () => _openReplyViewer(context, replyMsg)
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: primaryColor, width: 2)),
          color: isOutgoing
              ? colorScheme.onPrimary.withValues(alpha: 0.1)
              : colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  Text(
                    truncatedContent,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textColor),
                  ),
                ],
              ),
            ),
            if (hasPhoto) ...[
              const SizedBox(width: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.file(
                  File(displayPhotoPath),
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ] else if (isPhotoLoading) ...[
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openReplyViewer(BuildContext context, Message repliedMessage) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _ReplyPostViewer(message: repliedMessage);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
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
        return _buildVideoMessage(context);
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
    final hasCaption = message.content.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PhotoMessageWidget(
          photoPath: message.photo?.path,
          photoWidth: message.photo?.width,
          photoHeight: message.photo?.height,
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

  Widget _buildVideoMessage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasCaption = message.content.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VideoMessageWidget(
          videoPath: message.video?.path,
          videoWidth: message.video?.width,
          videoHeight: message.video?.height,
          duration: message.video?.duration,
          thumbnailPath: message.video?.thumbnailPath,
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
      stickerPath: message.sticker?.path,
      stickerWidth: message.sticker?.width,
      stickerHeight: message.sticker?.height,
      isAnimated: message.sticker?.isAnimated ?? false,
      emoji: message.sticker?.emoji,
    );
  }

  Widget _buildTextMessage(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
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
                  if ((reaction.type == ReactionType.emoji ||
                          reaction.type == ReactionType.paid) &&
                      reaction.emoji != null)
                    Text(reaction.emoji!, style: const TextStyle(fontSize: 14))
                  else if (reaction.type == ReactionType.customEmoji &&
                      reaction.customEmojiPath != null)
                    // Custom emoji with downloaded image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Image.file(
                        File(reaction.customEmojiPath!),
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Icon(
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

/// Full-screen viewer for reply posts
class _ReplyPostViewer extends StatelessWidget {
  final Message message;

  const _ReplyPostViewer({required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final photoPath = message.photo?.path ?? message.linkPreviewPhoto?.path;
    final hasPhoto = photoPath != null && photoPath.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: SafeArea(
          child: Column(
            children: [
              // Header with close button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.senderName ?? 'Channel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Photo if available
                      if (hasPhoto) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(photoPath),
                            fit: BoxFit.contain,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Text content
                      if (message.content.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SelectableText(
                            message.content,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                        ),
                      // Show message type indicator for media without caption
                      if (message.content.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _getTypeIcon(message.type),
                                color: colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getTypeName(message.type),
                                style: TextStyle(
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Date
                      Text(
                        DateFormat('MMM dd, yyyy HH:mm').format(message.date),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getTypeIcon(MessageType type) {
    switch (type) {
      case MessageType.photo:
        return Icons.photo;
      case MessageType.video:
        return Icons.videocam;
      case MessageType.sticker:
        return Icons.emoji_emotions;
      case MessageType.document:
        return Icons.description;
      case MessageType.audio:
        return Icons.audiotrack;
      case MessageType.voice:
        return Icons.mic;
      case MessageType.animation:
        return Icons.gif;
      case MessageType.text:
        return Icons.message;
    }
  }

  String _getTypeName(MessageType type) {
    switch (type) {
      case MessageType.photo:
        return 'Photo';
      case MessageType.video:
        return 'Video';
      case MessageType.sticker:
        return 'Sticker';
      case MessageType.document:
        return 'Document';
      case MessageType.audio:
        return 'Audio';
      case MessageType.voice:
        return 'Voice message';
      case MessageType.animation:
        return 'GIF';
      case MessageType.text:
        return 'Message';
    }
  }
}
