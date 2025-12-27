import 'dart:convert';
import 'package:logger/logger.dart';

class FileFormatter extends LogPrinter {
  final bool includeStackTrace;

  FileFormatter({this.includeStackTrace = true});

  @override
  List<String> log(LogEvent event) {
    final timestamp = DateTime.now().toIso8601String();

    final logEntry = <String, dynamic>{
      'timestamp': timestamp,
      'level': event.level.name.toUpperCase(),
      'message': _extractMessage(event.message),
    };

    // Add context if available
    if (event.message is Map) {
      final messageMap = event.message as Map<String, dynamic>;
      if (messageMap.containsKey('context')) {
        logEntry['context'] = messageMap['context'];
      }
      if (messageMap.containsKey('module')) {
        logEntry['module'] = messageMap['module'];
      }
    }

    // Add error information
    if (event.error != null) {
      logEntry['error'] = {
        'message': event.error.toString(),
        'type': event.error.runtimeType.toString(),
      };
    }

    // Add stack trace if available and enabled
    if (includeStackTrace && event.stackTrace != null) {
      logEntry['stackTrace'] = event.stackTrace.toString().split('\n');
    }

    try {
      return [jsonEncode(logEntry)];
    } catch (e) {
      // Fallback to simple string format if JSON encoding fails
      return [
        '$timestamp [${event.level.name.toUpperCase()}] ${_extractMessage(event.message)}',
      ];
    }
  }

  dynamic _extractMessage(dynamic message) {
    if (message is Map) {
      return message['message'] ?? message.toString();
    }
    return message;
  }
}
