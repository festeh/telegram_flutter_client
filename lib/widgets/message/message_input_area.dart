import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat.dart';
import '../../presentation/providers/app_providers.dart';

class MessageInputArea extends ConsumerStatefulWidget {
  final Chat chat;

  const MessageInputArea({
    Key? key,
    required this.chat,
  }) : super(key: key);

  @override
  ConsumerState<MessageInputArea> createState() => _MessageInputAreaState();
}

class _MessageInputAreaState extends ConsumerState<MessageInputArea> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isMultiline = false;
  String _currentText = '';

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
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

    // Clear the input immediately for better UX
    _textController.clear();
    setState(() {
      _currentText = '';
      _isMultiline = false;
    });

    // Send the message
    try {
      await ref.read(messageProvider.notifier).sendMessage(widget.chat.id, text);
    } catch (e) {
      // If sending fails, restore the text
      _textController.text = text;
      setState(() {
        _currentText = text;
      });
      
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _sendMessage(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSending = ref.watch(messageProvider.select((state) => state.valueOrNull?.isSending ?? false));
    final hasError = ref.watch(messageProvider.select((state) => state.hasError));
    
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE4E4E7),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasError) _buildErrorBanner(),
          _buildInputArea(isSending),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    final error = ref.watch(messageProvider.select((state) => state.error?.toString()));
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red[50],
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Colors.red[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error ?? 'An error occurred',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red[700],
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
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isSending) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Attachment button
          IconButton(
            onPressed: isSending ? null : _showAttachmentOptions,
            icon: const Icon(
              Icons.attach_file,
              color: Color(0xFF6B7280),
            ),
            tooltip: 'Attach file',
          ),
          // Text input
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 40,
                maxHeight: 120,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: _focusNode.hasFocus 
                      ? const Color(0xFF3390EC)
                      : const Color(0xFFE5E7EB),
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
                          color: isSending 
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF9CA3AF),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.3,
                      ),
                    ),
                  ),
                  // Emoji button
                  IconButton(
                    onPressed: isSending ? null : _showEmojiPicker,
                    icon: Icon(
                      Icons.emoji_emotions_outlined,
                      color: isSending 
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF6B7280),
                    ),
                    tooltip: 'Add emoji',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button
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
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: isSending 
            ? const Color(0xFFD1D5DB)
            : const Color(0xFF3390EC),
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
                    Colors.white.withOpacity(0.7),
                  ),
                ),
              )
            : const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
        tooltip: isSending ? 'Sending...' : 'Send message',
        splashRadius: 20,
      ),
    );
  }

  Widget _buildVoiceButton() {
    return Container(
      height: 40,
      width: 40,
      decoration: const BoxDecoration(
        color: Color(0xFF6B7280),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: _startVoiceRecording,
        icon: const Icon(
          Icons.mic,
          color: Colors.white,
          size: 20,
        ),
        tooltip: 'Voice message',
        splashRadius: 20,
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send Attachment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
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
                    // TODO: Implement gallery picker
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement camera
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement file picker
                  },
                ),
                _buildAttachmentOption(
                  icon: Icons.location_on,
                  label: 'Location',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement location sharing
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
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  void _showEmojiPicker() {
    // TODO: Implement emoji picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Emoji picker coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _startVoiceRecording() {
    // TODO: Implement voice recording
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice messages coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}