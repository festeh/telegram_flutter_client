import 'package:logger/logger.dart';
import 'app_logger.dart';
import 'log_level.dart';

class TdlibLogger {
  static TdlibLogger? _instance;
  static TdlibLogger get instance => _instance ??= TdlibLogger._();

  final AppLogger _logger = AppLogger.instance;

  TdlibLogger._();

  void logRequest(Map<String, dynamic> request, {String? requestId}) {
    _logger.tdlibLog(
      Level.debug,
      'TDLib Request: ${request['@type']}',
      requestId: requestId,
      metadata: {
        'request_type': request['@type'],
        'request_data': _sanitizeRequest(request),
      },
    );
  }

  void logResponse(Map<String, dynamic> response, {String? requestId}) {
    _logger.tdlibLog(
      Level.debug,
      'TDLib Response: ${response['@type']}',
      requestId: requestId,
      metadata: {
        'response_type': response['@type'],
        'response_data': _sanitizeResponse(response),
      },
    );
  }

  void logUpdate(Map<String, dynamic> update) {
    final updateType = update['@type'] as String;
    _logger.tdlibLog(
      Level.info,
      'TDLib Update: $updateType',
      metadata: {
        'update_type': updateType,
        'update_data': _sanitizeUpdate(update),
      },
    );
  }

  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.tdlibLog(
      Level.error,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void logConnectionState(String state) {
    _logger.tdlibLog(
      Level.info,
      'TDLib Connection State: $state',
      metadata: {'connection_state': state},
    );
  }

  void logAuthState(String state) {
    _logger.tdlibLog(
      Level.info,
      'TDLib Auth State: $state',
      metadata: {'auth_state': state},
    );
  }

  Map<String, dynamic> _sanitizeRequest(Map<String, dynamic> request) {
    final sanitized = Map<String, dynamic>.from(request);

    // Remove sensitive data
    sanitized.remove('api_hash');
    sanitized.remove('encryption_key');
    sanitized.remove('password');
    sanitized.remove('code');

    // Mask phone numbers
    if (sanitized.containsKey('phone_number')) {
      sanitized['phone_number'] = _maskPhoneNumber(sanitized['phone_number']);
    }

    return sanitized;
  }

  Map<String, dynamic> _sanitizeResponse(Map<String, dynamic> response) {
    final sanitized = Map<String, dynamic>.from(response);

    // Handle user data
    if (sanitized.containsKey('user')) {
      final user = sanitized['user'] as Map<String, dynamic>;
      if (user.containsKey('phone_number')) {
        user['phone_number'] = _maskPhoneNumber(user['phone_number']);
      }
    }

    return sanitized;
  }

  Map<String, dynamic> _sanitizeUpdate(Map<String, dynamic> update) {
    return _sanitizeResponse(update); // Use same logic as response
  }

  String _maskPhoneNumber(String phoneNumber) {
    if (phoneNumber.length <= 4) return '****';
    return '${phoneNumber.substring(0, 2)}****${phoneNumber.substring(phoneNumber.length - 2)}';
  }
}

class AuthLogger {
  static AuthLogger? _instance;
  static AuthLogger get instance => _instance ??= AuthLogger._();

  final AppLogger _logger = AppLogger.instance;

  AuthLogger._();

  void logAuthStart(String method) {
    _logger.authLog(
      Level.info,
      'Authentication started: $method',
      metadata: {'auth_method': method},
    );
  }

  void logAuthSuccess(String userId) {
    _logger.authLog(Level.info, 'Authentication successful', userId: userId);
  }

  void logAuthFailure(String reason, {Object? error}) {
    _logger.authLog(
      Level.warning,
      'Authentication failed: $reason',
      error: error,
      metadata: {'failure_reason': reason},
    );
  }

  void logPhoneNumberSubmission() {
    _logger.authLog(Level.debug, 'Phone number submitted');
  }

  void logCodeSubmission() {
    _logger.authLog(Level.debug, 'Verification code submitted');
  }

  void logPasswordSubmission() {
    _logger.authLog(Level.debug, 'Password submitted');
  }

  void logQrCodeRequest() {
    _logger.authLog(Level.debug, 'QR code authentication requested');
  }

  void logLogout(String? userId) {
    _logger.authLog(Level.info, 'User logged out', userId: userId);
  }

  void logSessionLoad() {
    _logger.authLog(Level.debug, 'Session loaded from storage');
  }

  void logSessionSave() {
    _logger.authLog(Level.debug, 'Session saved to storage');
  }

  void logError(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.authLog(Level.error, message, error: error, stackTrace: stackTrace);
  }
}

class NetworkLogger {
  static NetworkLogger? _instance;
  static NetworkLogger get instance => _instance ??= NetworkLogger._();

  final AppLogger _logger = AppLogger.instance;

  NetworkLogger._();

  void logRequest(
    String method,
    String url, {
    String? requestId,
    Map<String, String>? headers,
    dynamic body,
  }) {
    _logger.networkLog(
      Level.debug,
      'HTTP Request: $method $url',
      requestId: requestId,
      metadata: {
        'method': method,
        'url': url,
        'headers': headers,
        'body': body,
      },
    );
  }

  void logResponse(
    int statusCode,
    String url, {
    String? requestId,
    Duration? duration,
  }) {
    _logger.networkLog(
      Level.debug,
      'HTTP Response: $statusCode for $url',
      requestId: requestId,
      metadata: {
        'status_code': statusCode,
        'url': url,
        if (duration != null) 'duration_ms': duration.inMilliseconds,
      },
    );
  }

  void logError(
    String message, {
    String? requestId,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _logger.networkLog(
      Level.error,
      message,
      requestId: requestId,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

class PerformanceLogger {
  static PerformanceLogger? _instance;
  static PerformanceLogger get instance => _instance ??= PerformanceLogger._();

  final AppLogger _logger = AppLogger.instance;
  final Map<String, DateTime> _operationStarts = {};

  PerformanceLogger._();

  void startOperation(String operationId) {
    _operationStarts[operationId] = DateTime.now();
  }

  void endOperation(String operationId, {Map<String, dynamic>? metadata}) {
    final startTime = _operationStarts.remove(operationId);
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _logger.performanceLog(operationId, duration, metadata: metadata);
    }
  }

  void logMemoryUsage(int bytesUsed) {
    _logger.info(
      'Memory usage: ${(bytesUsed / 1024 / 1024).toStringAsFixed(2)} MB',
      context: const LogContext(module: LogModule.performance),
    );
  }

  void logFrameRate(double fps) {
    _logger.info(
      'Frame rate: ${fps.toStringAsFixed(1)} FPS',
      context: const LogContext(module: LogModule.performance),
    );
  }
}
