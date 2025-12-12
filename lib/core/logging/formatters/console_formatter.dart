import 'package:logger/logger.dart';

class ConsoleFormatter extends LogPrinter {
  final bool includeEmojis;
  final bool includeTimestamp;
  final bool includeModule;

  ConsoleFormatter({
    this.includeEmojis = true,
    this.includeTimestamp = true,
    this.includeModule = true,
  });

  @override
  List<String> log(LogEvent event) {
    final buffer = StringBuffer();

    // Add timestamp
    if (includeTimestamp) {
      buffer.write('${DateTime.now().toIso8601String()} ');
    }

    // Add level name without color
    final levelName = event.level.name.toUpperCase().padRight(5);
    buffer.write('$levelName ');

    // Add module info if available
    if (includeModule && event.message is Map) {
      final messageMap = event.message as Map<String, dynamic>;
      if (messageMap.containsKey('module')) {
        final module = messageMap['module'] as String;
        buffer.write('[$module] ');
      }
    }

    // Add the actual message
    if (event.message is Map) {
      final messageMap = event.message as Map<String, dynamic>;
      final actualMessage = messageMap['message'] ?? messageMap.toString();
      buffer.write(actualMessage);

      // Add context if available on same line
      if (messageMap.containsKey('context') && messageMap['context'] != null) {
        final context = messageMap['context'] as Map<String, dynamic>;
        buffer.write(' | Context: ${_formatContext(context)}');
      }
    } else {
      buffer.write(event.message);
    }

    // Add error on same line
    if (event.error != null) {
      buffer.write(' | Error: ${event.error}');
    }

    // Add stack trace on same line (truncated for readability)
    if (event.stackTrace != null) {
      final stackLines = event.stackTrace.toString().split('\n');
      final firstLine = stackLines.isNotEmpty ? stackLines[0] : '';
      buffer.write(' | Stack: $firstLine');
    }

    return [buffer.toString()];
  }

  String _formatContext(Map<String, dynamic> context) {
    final items = <String>[];

    for (final entry in context.entries) {
      if (entry.value != null) {
        items.add('${entry.key}=${entry.value}');
      }
    }

    return items.join(', ');
  }
}
