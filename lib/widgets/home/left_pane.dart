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
          _buildFilterTabs(colorScheme),
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

  Widget _buildFilterTabs(ColorScheme colorScheme) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab('All', true, colorScheme),
                  const SizedBox(width: 6),
                  _buildFilterTab('Unread', false, colorScheme),
                  const SizedBox(width: 6),
                  _buildFilterTab('Favorites', false, colorScheme),
                ],
              ),
            ),
          ),
          // Archive button
          IconButton(
            onPressed: () {
              // TODO: Implement archive functionality
            },
            icon: Icon(
              Icons.archive_outlined,
              size: 18,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            tooltip: 'Archive',
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, bool isActive, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        // TODO: Implement filter functionality
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isActive
              ? null
              : Border.all(
                  color: colorScheme.outline,
                  width: 1,
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w500 : FontWeight.w400,
            color: isActive
                ? colorScheme.onPrimary
                : colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
