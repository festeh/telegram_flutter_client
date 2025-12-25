import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/app_providers.dart';
import '../presentation/providers/telegram_client_provider.dart';
import '../domain/entities/chat.dart';
import '../widgets/home/left_pane.dart';
import '../widgets/message/message_list.dart';
import '../widgets/message/message_input_area.dart';
import 'chat_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (_isMobile) {
      return _buildMobileLayout(context, ref);
    }
    return _buildDesktopLayout(context, ref);
  }

  Widget _buildMobileLayout(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: LeftPane(
          onChatSelected: (chat) {
            ref.selectChatForMessages(chat.id);
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(chat: chat),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, WidgetRef ref) {
    final selectedChat = ref.selectedChat;

    return Scaffold(
      body: Row(
        children: [
          // Left Pane - Chat List (30% of screen width)
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: LeftPane(
              onChatSelected: (chat) {
                ref.selectChatForMessages(chat.id);
              },
            ),
          ),
          // Right Pane - Chat Content (70% of screen width)
          Expanded(
            child: selectedChat != null
                ? _buildChatInterface(context, ref, selectedChat)
                : _buildEmptyPane(context),
          ),
        ],
      ),
    );
  }

  Widget _buildChatInterface(BuildContext context, WidgetRef ref, Chat chat) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Chat Header
          _buildChatHeader(context, ref, chat, colorScheme),
          // Messages Area
          Expanded(
            child: Container(
              color: colorScheme.surface,
              child: MessageList(chat: chat),
            ),
          ),
          // Message Input Area
          MessageInputArea(chat: chat),
        ],
      ),
    );
  }

  Widget _buildChatHeader(BuildContext context, WidgetRef ref, Chat chat, ColorScheme colorScheme) {
    final mutedColor = colorScheme.onSurface.withValues(alpha: 0.6);
    final client = ref.read(telegramClientProvider);

    // Get status text based on chat type
    String statusText = _getChatStatusText(chat, client);

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Chat avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary,
              image: chat.photoPath != null
                  ? DecorationImage(
                      image: FileImage(File(chat.photoPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: chat.photoPath == null
                ? Center(
                    child: Text(
                      chat.title.isNotEmpty ? chat.title[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Chat info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  chat.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (statusText.isNotEmpty)
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusText == 'online'
                          ? colorScheme.primary
                          : mutedColor,
                    ),
                  ),
              ],
            ),
          ),
          // Action buttons
          IconButton(
            onPressed: () {
              // TODO: Implement search in chat
            },
            icon: Icon(
              Icons.search,
              color: mutedColor,
            ),
            tooltip: 'Search in chat',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: 8),
                    Text('Chat info'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
            child: Icon(
              Icons.more_vert,
              color: mutedColor,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyPane(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(color: colorScheme.surface);
  }

  String _getChatStatusText(Chat chat, dynamic client) {
    switch (chat.type) {
      case ChatType.private:
        // For private chats, the user ID equals the chat ID
        final status = client.getUserStatus(chat.id);
        return status ?? '';
      case ChatType.basicGroup:
      case ChatType.supergroup:
      case ChatType.channel:
      case ChatType.secret:
        return '';
    }
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              ref.logout();
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
