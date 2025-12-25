import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat.dart';
import '../chat/chat_list.dart';

class LeftPane extends ConsumerStatefulWidget {
  final Function(Chat)? onChatSelected;

  const LeftPane({
    super.key,
    this.onChatSelected,
  });

  @override
  ConsumerState<LeftPane> createState() => _LeftPaneState();
}

class _LeftPaneState extends ConsumerState<LeftPane> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          right: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(colorScheme),
          Expanded(
            child: ChatList(
              onChatSelected: widget.onChatSelected,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          // Menu icon
          IconButton(
            onPressed: () {
              // TODO: Implement menu functionality
            },
            icon: Icon(
              Icons.menu,
              size: 24,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            tooltip: 'Menu',
          ),
          const SizedBox(width: 8),
          // Title
          Expanded(
            child: Text(
              'Chats',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          // New chat button
          IconButton(
            onPressed: () {
              // TODO: Implement new chat functionality
            },
            icon: Icon(
              Icons.edit_outlined,
              size: 24,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            tooltip: 'New Chat',
          ),
        ],
      ),
    );
  }

}
