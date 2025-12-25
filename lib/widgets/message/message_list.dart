import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat.dart';
import '../../presentation/providers/app_providers.dart';
import '../common/state_widgets.dart';
import 'message_bubble.dart';
import 'date_separator.dart';

class MessageList extends ConsumerStatefulWidget {
  final Chat chat;

  const MessageList({
    super.key,
    required this.chat,
  });

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  late ScrollController _scrollController;
  bool _isAutoScrolling = false;
  bool _shouldAutoScroll = true;
  int? _lastMarkedMessageId;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    
    // Load messages for this chat when widget is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(messageProvider.notifier).selectChat(widget.chat.id);
      ref.read(messageProvider.notifier).loadMessages(widget.chat.id);
    });
  }

  @override
  void didUpdateWidget(MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When chat changes, load messages for the new chat
    if (oldWidget.chat.id != widget.chat.id) {
      _lastMarkedMessageId = null; // Reset for new chat
      // Delay the provider modification to avoid modifying during build
      Future(() {
        ref.read(messageProvider.notifier).selectChat(widget.chat.id);
        ref.read(messageProvider.notifier).loadMessages(widget.chat.id);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final currentScrollPosition = _scrollController.offset;

      // With reverse: true, offset 0 = bottom (newest messages visible)
      // Show scroll-to-bottom button when scrolled away from newest messages
      _shouldAutoScroll = currentScrollPosition < 100;

      // Load more messages when scrolling to the top (older messages)
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreMessages();
      }
    }
  }

  void _loadMoreMessages() {
    if (!ref.read(messageProvider.select((state) => state.value?.isLoadingMore ?? false))) {
      ref.read(messageProvider.notifier).loadMoreMessages(widget.chat.id);
    }
  }

  void _markLatestAsRead(List<Message>? messages) {
    if (messages == null || messages.isEmpty) return;

    // Find the latest incoming message (messages are sorted newest first)
    final latestIncoming = messages.cast<Message?>().firstWhere(
      (m) => m != null && !m.isOutgoing,
      orElse: () => null,
    );

    if (latestIncoming == null) return;

    // Don't mark the same message twice
    if (_lastMarkedMessageId == latestIncoming.id) return;

    _lastMarkedMessageId = latestIncoming.id;
    ref.read(messageProvider.notifier).markAsRead(widget.chat.id, latestIncoming.id);
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollController.hasClients && !_isAutoScrolling) {
      _isAutoScrolling = true;
      
      if (animated) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ).then((_) => _isAutoScrolling = false);
      } else {
        _scrollController.jumpTo(0.0);
        _isAutoScrolling = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to message updates for this chat
    ref.listen(messageProvider.select((state) => state.value?.selectedChatMessages),
      (prev, next) {
        if (next != null && prev != null && next.length > prev.length && _shouldAutoScroll) {
          // New message arrived, scroll to bottom and mark as read
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
            _markLatestAsRead(next);
          });
        }
      }
    );

    final messageState = ref.watch(messageProvider).value;
    final isLoadingMore = ref.watch(messageProvider.select((state) => state.value?.isLoadingMore ?? false));
    final hasError = ref.watch(messageProvider.select((state) => state.hasError));
    final error = ref.watch(messageProvider.select((state) => state.error?.toString()));
    
    if (hasError && error != null) {
      return _buildErrorState(error);
    }

    final messages = messageState?.messagesByChat[widget.chat.id];
    final isChatInitialized = messageState?.isChatInitialized(widget.chat.id) ?? false;

    // Show loading if messages not loaded yet OR chat hasn't completed initialization
    if (messages == null || !isChatInitialized) {
      return _buildLoadingState();
    }

    // Empty list with initialization complete means truly no messages
    if (messages.isEmpty) {
      return _buildEmptyState();
    }

    // Mark latest message as read when messages are displayed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markLatestAsRead(messages);
    });

    return Stack(
      children: [
        Column(
          children: [
            if (isLoadingMore) _buildLoadingMoreIndicator(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _refreshMessages(),
                child: ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Show newest messages at bottom
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isLastInGroup = _isLastInGroup(messages, index);
                    final showSender = !message.isOutgoing && isLastInGroup;
                    final showDateSeparator = _shouldShowDateSeparator(messages, index);

                    return Column(
                      children: [
                        if (showDateSeparator)
                          DateSeparator(date: message.date),
                        MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          showTime: isLastInGroup,
                          showSender: showSender,
                          onLongPress: () => _showMessageOptions(context, message),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        if (!_shouldAutoScroll) _buildScrollToBottomButton(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const LoadingStateWidget(message: 'Loading messages...');
  }

  Widget _buildEmptyState() {
    return const EmptyStateWidget(
      icon: Icons.chat_bubble_outline,
      title: 'No messages yet',
      subtitle: 'Start the conversation by sending a message',
    );
  }

  Widget _buildErrorState(String error) {
    return ErrorStateWidget(
      title: 'Failed to load messages',
      error: error,
      onRetry: _refreshMessages,
      useErrorColor: true,
    );
  }

  Widget _buildLoadingMoreIndicator() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Loading more messages...',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomButton() {
    final colorScheme = Theme.of(context).colorScheme;

    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton.small(
        onPressed: () => _scrollToBottom(),
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        child: const Icon(Icons.keyboard_arrow_down),
      ),
    );
  }

  bool _isLastInGroup(List<Message> messages, int index) {
    if (index == 0) return true;

    final currentMessage = messages[index];
    final nextMessage = messages[index - 1]; // Remember: reverse order

    // Different sender
    if (currentMessage.senderId != nextMessage.senderId) return true;

    // More than 5 minutes apart
    final timeDifference = nextMessage.date.difference(currentMessage.date);
    if (timeDifference.inMinutes > 5) return true;

    return false;
  }

  bool _shouldShowDateSeparator(List<Message> messages, int index) {
    // In reversed list: index 0 = newest (bottom), higher index = older (top)
    // Show separator when this message starts a new day compared to the next older message
    if (index == messages.length - 1) return true; // Always show for oldest message

    final currentMessage = messages[index];
    final nextOlderMessage = messages[index + 1];

    final currentDay = DateTime(
      currentMessage.date.year,
      currentMessage.date.month,
      currentMessage.date.day,
    );
    final nextOlderDay = DateTime(
      nextOlderMessage.date.year,
      nextOlderMessage.date.month,
      nextOlderMessage.date.day,
    );

    return currentDay != nextOlderDay;
  }

  Future<void> _refreshMessages() async {
    await ref.read(messageProvider.notifier).loadMessages(
      widget.chat.id, 
      forceRefresh: true,
    );
  }

  void _showMessageOptions(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.isOutgoing) ...[
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement reply functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Copy'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement copy functionality
              },
            ),
            ListTile(
              leading: const Icon(Icons.forward),
              title: const Text('Forward'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement forward functionality
              },
            ),
          ],
        ),
      ),
    );
  }

  void _editMessage(Message message) {
    final textController = TextEditingController(text: message.content);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextFormField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Enter new message...',
          ),
          autofocus: true,
          onFieldSubmitted: (newText) {
            if (newText.trim().isNotEmpty) {
              ref.read(messageProvider.notifier).editMessage(
                widget.chat.id,
                message.id,
                newText.trim(),
              );
            }
            Navigator.pop(dialogContext);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newText = textController.text.trim();
              if (newText.isNotEmpty && newText != message.content) {
                ref.read(messageProvider.notifier).editMessage(
                  widget.chat.id,
                  message.id,
                  newText,
                );
              }
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => textController.dispose());
  }

  void _deleteMessage(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(messageProvider.notifier).deleteMessage(
                widget.chat.id, 
                message.id,
              );
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}