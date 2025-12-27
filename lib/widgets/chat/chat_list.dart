import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat.dart';
import '../../presentation/providers/app_providers.dart';
import '../../presentation/providers/telegram_client_provider.dart';
import '../common/state_widgets.dart';
import 'chat_list_item.dart';

class ChatList extends ConsumerStatefulWidget {
  final Function(Chat)? onChatSelected;

  const ChatList({
    super.key,
    this.onChatSelected,
  });

  @override
  ConsumerState<ChatList> createState() => _ChatListState();
}

class _ChatListState extends ConsumerState<ChatList> {
  int? _selectedChatId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Add scroll listener for pagination
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      // Load more chats when reaching the bottom
      ref.loadMoreChats();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final chatAsync = ref.watch(chatProvider);

        return chatAsync.when(
          data: (chatState) =>
              _buildChatList(chatState.chats, chatState.isLoading, chatState.isInitialized),
          loading: () => _buildLoadingState(),
          error: (error, stackTrace) => _buildErrorState(error.toString()),
        );
      },
    );
  }

  Widget _buildChatList(List<Chat> chats, bool isLoadingMore, bool isInitialized) {
    final colorScheme = Theme.of(context).colorScheme;

    // Filter to show only chats in the main list (as determined by TDLib positions)
    final filteredChats = chats.where((chat) => chat.isInMainList).toList();

    if (filteredChats.isEmpty) {
      // Only show "No chats" if we've finished initial load
      return isInitialized ? _buildEmptyState() : _buildLoadingState();
    }

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // Force TDLib to reconnect before refreshing
              await ref.read(telegramClientProvider).setNetworkType(isOnline: true);
              await ref.refreshChats();
            },
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: filteredChats.length + (isLoadingMore ? 1 : 0),
              separatorBuilder: (context, index) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                if (index >= filteredChats.length) {
                  // Show loading indicator at the bottom when loading more
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(colorScheme.primary),
                      ),
                    ),
                  );
                }

                final chat = filteredChats[index];
                return ChatListItem(
                  chat: chat,
                  isSelected: _selectedChatId == chat.id,
                  onTap: () => _onChatTap(chat),
                );
              },
            ),
          ),
        ),
        if (ref.hasChatError) _buildErrorBanner(),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const LoadingStateWidget(message: 'Loading chats...');
  }

  Widget _buildEmptyState() {
    return EmptyStateWidget(
      icon: Icons.chat_outlined,
      title: 'No chats yet',
      subtitle: 'Start a conversation to see your chats here',
      actionLabel: 'Refresh',
      onAction: () => ref.refreshChats(),
    );
  }

  Widget _buildErrorState(String error) {
    return ErrorStateWidget(
      title: 'Failed to load chats',
      error: error,
      onRetry: () => ref.refreshChats(),
    );
  }

  Widget _buildErrorBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    final error = ref.chatError;
    if (error == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: colorScheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            onPressed: () => ref.clearChatError(),
            icon: Icon(
              Icons.close,
              size: 20,
              color: colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  void _onChatTap(Chat chat) {
    setState(() {
      _selectedChatId = chat.id;
    });

    // Call the callback if provided
    widget.onChatSelected?.call(chat);
  }
}
