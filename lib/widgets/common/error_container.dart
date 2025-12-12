import 'package:flutter/material.dart';

/// A styled container for displaying error messages with an icon.
class ErrorContainer extends StatelessWidget {
  final String message;
  final EdgeInsets padding;
  final double borderRadius;

  const ErrorContainer({
    super.key,
    required this.message,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = 6,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error,
            color: colorScheme.onErrorContainer,
            size: 18,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
