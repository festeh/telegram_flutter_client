import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat.dart';
import '../../presentation/providers/app_providers.dart';
import '../emoji_sticker/emoji_sticker_picker.dart';

class MessageInputArea extends ConsumerStatefulWidget {
  final Chat chat;

  const MessageInputArea({
    super.key,
    required this.chat,
  });

  @override
  ConsumerState<MessageInputArea> createState() => _MessageInputAreaState();
}

class _MessageInputAreaState extends ConsumerState<MessageInputArea>
    with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isMultiline = false;
  String _currentText = '';
  bool _wasKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textController.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _updateKeyboardHeight();
  }

  void _updateKeyboardHeight() {
    final viewInsets = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets;
    final devicePixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final keyboardHeight = viewInsets.bottom / devicePixelRatio;

    final isKeyboardVisible = keyboardHeight > 0;

    if (keyboardHeight > 50) {
      // Store keyboard height for picker
      ref.read(emojiStickerProvider.notifier).setKeyboardHeight(keyboardHeight);
    }

    // If keyboard just appeared while picker is visible, hide picker
    if (isKeyboardVisible && !_wasKeyboardVisible && ref.read(emojiStickerProvider).isPickerVisible) {
      ref.read(emojiStickerProvider.notifier).hidePicker();
    }

    _wasKeyboardVisible = isKeyboardVisible;
  }

  void _onFocusChanged() {
    // When text field gains focus from tap, hide picker
    if (_focusNode.hasFocus && ref.read(emojiStickerProvider).isPickerVisible) {
      ref.read(emojiStickerProvider.notifier).hidePicker();
    }
    setState(() {});
  }

  void _onTextChanged() {
    final text = _textController.text;
    setState(() {
      _currentText = text;
      _isMultiline = text.contains('\n') || text.length > 50;
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    setState(() {
      _currentText = '';
      _isMultiline = false;
    });

    try {
      await ref.read(messageProvider.notifier).sendMessage(widget.chat.id, text);
    } catch (e) {
      _textController.text = text;
      setState(() {
        _currentText = text;
      });

      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: colorScheme.onError,
              onPressed: () => _sendMessage(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSending = ref.watch(messageProvider.select((state) => state.valueOrNull?.isSending ?? false));
    final hasError = ref.watch(messageProvider.select((state) => state.hasError));
    final isPickerVisible = ref.watch(emojiStickerProvider.select((s) => s.isPickerVisible));
    final pickerHeight = ref.watch(emojiStickerProvider.select((s) => s.keyboardHeight));

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasError) _buildErrorBanner(),
          _buildInputArea(isSending),
          if (isPickerVisible)
            EmojiStickerPicker(
              height: pickerHeight > 0 ? pickerHeight : 300,
              textController: _textController,
              chatId: widget.chat.id,
              onEmojiSelected: () {
                // Keep focus on text field for continued typing
              },
              onStickerSent: () {
                // Optionally hide picker after sending sticker
                ref.read(emojiStickerProvider.notifier).hidePicker();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    final error = ref.watch(messageProvider.select((state) => state.error?.toString()));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error ?? 'An error occurred',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onErrorContainer,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => ref.read(messageProvider.notifier).clearError(),
            child: Text(
              'Dismiss',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isSending) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: isSending ? null : _showAttachmentOptions,
            icon: Icon(
              Icons.attach_file,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            tooltip: 'Attach file',
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 40,
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? colorScheme.primary
                      : colorScheme.outline,
                  width: _focusNode.hasFocus ? 2 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      enabled: !isSending,
                      maxLines: null,
                      textInputAction: _isMultiline
                          ? TextInputAction.newline
                          : TextInputAction.send,
                      onSubmitted: (_) {
                        if (!_isMultiline) {
                          _sendMessage();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: isSending ? 'Sending...' : 'Type a message...',
                        hintStyle: TextStyle(
                          color: colorScheme.onSurface.withValues(alpha: isSending ? 0.3 : 0.5),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.3,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: isSending ? null : _showEmojiPicker,
                    icon: Icon(
                      ref.watch(emojiStickerProvider.select((s) => s.isPickerVisible))
                          ? Icons.keyboard_outlined
                          : Icons.emoji_emotions_outlined,
                      color: colorScheme.onSurface.withValues(alpha: isSending ? 0.3 : 0.6),
                    ),
                    tooltip: ref.watch(emojiStickerProvider.select((s) => s.isPickerVisible))
                        ? 'Show keyboard'
                        : 'Add emoji',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: _currentText.trim().isNotEmpty || isSending
                ? _buildSendButton(isSending)
                : _buildVoiceButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(bool isSending) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: isSending
            ? colorScheme.surfaceContainerHighest
            : colorScheme.primary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: isSending ? null : _sendMessage,
        icon: isSending
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              )
            : Icon(
                Icons.send,
                color: colorScheme.onPrimary,
                size: 20,
              ),
        tooltip: isSending ? 'Sending...' : 'Send message',
        splashRadius: 20,
      ),
    );
  }

  Widget _buildVoiceButton() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: colorScheme.secondary,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: _startVoiceRecording,
        icon: Icon(
          Icons.mic,
          color: colorScheme.onSecondary,
          size: 20,
        ),
        tooltip: 'Voice message',
        splashRadius: 20,
      ),
    );
  }

  void _showAttachmentOptions() {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Send Attachment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: colorScheme.primary,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_on,
                  label: 'Location',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmojiPicker() {
    final isPickerVisible = ref.read(emojiStickerProvider).isPickerVisible;

    if (isPickerVisible) {
      // Hide picker and show keyboard
      ref.read(emojiStickerProvider.notifier).hidePicker();
      _focusNode.requestFocus();
    } else {
      // Hide keyboard and show picker
      _focusNode.unfocus();
      ref.read(emojiStickerProvider.notifier).showPicker();
    }
  }

  void _startVoiceRecording() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice messages coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
