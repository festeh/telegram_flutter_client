enum LogModule {
  auth,
  tdlib,
  network,
  storage,
  ui,
  performance,
  general,
}

extension LogModuleExtension on LogModule {
  String get name {
    switch (this) {
      case LogModule.auth:
        return 'AUTH';
      case LogModule.tdlib:
        return 'TDLIB';
      case LogModule.network:
        return 'NETWORK';
      case LogModule.storage:
        return 'STORAGE';
      case LogModule.ui:
        return 'UI';
      case LogModule.performance:
        return 'PERF';
      case LogModule.general:
        return 'GENERAL';
    }
  }

  String get emoji {
    switch (this) {
      case LogModule.auth:
        return '🔐';
      case LogModule.tdlib:
        return '📱';
      case LogModule.network:
        return '🌐';
      case LogModule.storage:
        return '💾';
      case LogModule.ui:
        return '🎨';
      case LogModule.performance:
        return '⚡';
      case LogModule.general:
        return '🔧';
    }
  }
}

class LogContext {
  final LogModule module;
  final String? userId;
  final String? sessionId;
  final String? requestId;
  final Map<String, dynamic>? metadata;

  const LogContext({
    required this.module,
    this.userId,
    this.sessionId,
    this.requestId,
    this.metadata,
  });

  LogContext copyWith({
    LogModule? module,
    String? userId,
    String? sessionId,
    String? requestId,
    Map<String, dynamic>? metadata,
  }) {
    return LogContext(
      module: module ?? this.module,
      userId: userId ?? this.userId,
      sessionId: sessionId ?? this.sessionId,
      requestId: requestId ?? this.requestId,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'module': module.name,
      if (userId != null) 'userId': _maskSensitive(userId!),
      if (sessionId != null) 'sessionId': sessionId,
      if (requestId != null) 'requestId': requestId,
      if (metadata != null) ...metadata!,
    };
  }

  String _maskSensitive(String value) {
    if (value.length <= 4) return '***';
    return '${value.substring(0, 2)}***${value.substring(value.length - 2)}';
  }
}
