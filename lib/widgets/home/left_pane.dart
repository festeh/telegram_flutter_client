import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/chat.dart';
import '../chat/chat_list.dart';

class LeftPane extends ConsumerStatefulWidget {
  final Function(Chat)? onChatSelected;

  const LeftPane({
    Key? key,
    this.onChatSelected,
  }) : super(key: key);

  @override
  ConsumerState<LeftPane> createState() => _LeftPaneState();
}

class _LeftPaneState extends ConsumerState<LeftPane> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

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
          _buildSearchBar(colorScheme),
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

  Widget _buildSearchBar(ColorScheme colorScheme) {
    final mutedColor = colorScheme.onSurface.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          // TODO: Implement search functionality
        },
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(
            color: mutedColor,
            fontSize: 16,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: mutedColor,
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                    _searchFocusNode.unfocus();
                  },
                  icon: Icon(
                    Icons.clear,
                    color: mutedColor,
                    size: 20,
                  ),
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerHigh,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: colorScheme.outline,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: colorScheme.outline,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(
              color: colorScheme.primary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        style: TextStyle(
          fontSize: 16,
          color: colorScheme.onSurface,
        ),
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
