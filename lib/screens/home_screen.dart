import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/providers/app_providers.dart';
import '../domain/entities/chat.dart';
import '../widgets/home/left_pane.dart';
import '../widgets/message/message_list.dart';
import '../widgets/message/message_input_area.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Chat? _selectedChat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Left Pane - Chat List (30% of screen width)
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: LeftPane(
              onChatSelected: (chat) {
                setState(() {
                  _selectedChat = chat;
                });
              },
            ),
          ),
          // Right Pane - Chat Content (70% of screen width)
          Expanded(
            child: _buildRightPane(),
          ),
        ],
      ),
    );
  }

  Widget _buildRightPane() {
    if (_selectedChat != null) {
      // When a chat is selected, show chat interface (placeholder for now)
      return _buildChatInterface(_selectedChat!);
    } else {
      // When no chat is selected, show welcome screen
      return _buildWelcomeScreen();
    }
  }

  Widget _buildChatInterface(Chat chat) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          // Chat Header
          _buildChatHeader(chat, colorScheme),
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

  Widget _buildChatHeader(Chat chat, ColorScheme colorScheme) {
    final mutedColor = colorScheme.onSurface.withValues(alpha: 0.6);

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
            ),
            child: Center(
              child: Text(
                chat.title.isNotEmpty ? chat.title[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onPrimary,
                ),
              ),
            ),
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
                Text(
                  'online', // Placeholder - will implement proper online status later
                  style: TextStyle(
                    fontSize: 12,
                    color: mutedColor,
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


  Widget _buildWelcomeScreen() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // User info section
            Builder(
              builder: (context) {
                final user = ref.currentUser;
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: colorScheme.primary,
                      child: Text(
                        user?.displayName.isNotEmpty == true
                            ? user!.displayName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome, ${user?.displayName ?? 'User'}!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (user?.username.isNotEmpty == true)
                      Text(
                        '@${user!.username}',
                        style: TextStyle(
                          fontSize: 16,
                          color: colorScheme.primary,
                        ),
                      ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
            // Welcome message
            Icon(
              Icons.chat_outlined,
              size: 80,
              color: colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Select a chat to start messaging',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a conversation from the list to begin chatting',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Logout button
            ElevatedButton.icon(
              onPressed: () => _showLogoutDialog(context, ref),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.surfaceContainerHigh,
                foregroundColor: colorScheme.onSurface.withValues(alpha: 0.7),
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: BorderSide(color: colorScheme.outline),
              ),
            ),
          ],
        ),
      ),
    );
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
