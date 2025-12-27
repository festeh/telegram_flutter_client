import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat.dart';
import '../../presentation/providers/app_providers.dart';
import 'chat_list_item.dart';

class ChatPickerSheet extends ConsumerWidget {
  final Function(Chat) onChatSelected;
  final int? excludeChatId;

  const ChatPickerSheet({
    super.key,
    required this.onChatSelected,
    this.excludeChatId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final chatAsync = ref.watch(chatProvider);

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.forward,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Forward to...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            // Chat list
            Flexible(
              child: chatAsync.when(
                data: (chatState) => _buildChatList(context, chatState.chats),
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('Failed to load chats: $error'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList(BuildContext context, List<Chat> chats) {
    // Filter to main list chats and exclude current chat
    final filteredChats = chats
        .where((chat) => chat.isInMainList && chat.id != excludeChatId)
        .toList();

    if (filteredChats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No chats available'),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: filteredChats.length,
      separatorBuilder: (context, index) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final chat = filteredChats[index];
        return ChatListItem(
          chat: chat,
          onTap: () {
            Navigator.pop(context);
            onChatSelected(chat);
          },
        );
      },
    );
  }
}
