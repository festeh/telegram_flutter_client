import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/app_providers.dart';
import '../presentation/providers/telegram_client_provider.dart';
import '../domain/entities/chat.dart';
import '../widgets/message/message_list.dart';
import '../widgets/message/message_input_area.dart';

class ChatScreen extends ConsumerWidget {
  final Chat chat;

  const ChatScreen({super.key, required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: _buildAppBar(context, ref, colorScheme),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: colorScheme.surface,
              child: MessageList(chat: chat),
            ),
          ),
          MessageInputArea(chat: chat),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, WidgetRef ref, ColorScheme colorScheme) {
    final mutedColor = colorScheme.onSurface.withValues(alpha: 0.6);
    final client = ref.read(telegramClientProvider);
    final statusText = _getChatStatusText(chat, client);

    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
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
                      color:
                          statusText == 'online' ? colorScheme.primary : mutedColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: Icon(Icons.search, color: mutedColor),
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
        ),
      ],
    );
  }

  String _getChatStatusText(Chat chat, dynamic client) {
    switch (chat.type) {
      case ChatType.private:
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
