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
    return Container(
      color: const Color(0xFFF8F9FA),
      child: Column(
        children: [
          // Chat Header
          _buildChatHeader(chat),
          // Messages Area
          Expanded(
            child: Container(
              color: const Color(0xFFF8F9FA),
              child: MessageList(chat: chat),
            ),
          ),
          // Message Input Area
          MessageInputArea(chat: chat),
        ],
      ),
    );
  }

  Widget _buildChatHeader(Chat chat) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE4E4E7),
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
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF3390EC),
            ),
            child: Center(
              child: Text(
                chat.title.isNotEmpty ? chat.title[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'online', // Placeholder - will implement proper online status later
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
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
            icon: const Icon(
              Icons.search,
              color: Color(0xFF6B7280),
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
            child: const Icon(
              Icons.more_vert,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildWelcomeScreen() {
    return Container(
      color: const Color(0xFFF8F9FA),
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
                      backgroundColor: const Color(0xFF3390EC),
                      child: Text(
                        user?.displayName.isNotEmpty == true
                            ? user!.displayName[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome, ${user?.displayName ?? 'User'}!',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (user?.username.isNotEmpty == true)
                      Text(
                        '@${user!.username}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF3390EC),
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
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Select a chat to start messaging',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose a conversation from the list to begin chatting',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
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
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF6B7280),
                elevation: 2,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
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
