import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import 'app_logger.dart';
import 'log_level.dart';
import 'tdlib_log_level.dart';

class LoggingConfig {
  static TdLibLogLevel? _tdlibLogLevel;

  /// Get the current TDLib log level
  static TdLibLogLevel get tdlibLogLevel =>
      _tdlibLogLevel ?? TdLibLogLevel.getDefault(kDebugMode, kReleaseMode);

  static Future<void> initialize({TdLibLogLevel? tdlibLogLevel}) async {
    Level logLevel;
    bool enableFileLogging;
    String? logDirectory;

    // Store TDLib log level for later use
    _tdlibLogLevel = tdlibLogLevel;

    // Configure based on build mode
    if (kDebugMode) {
      logLevel = Level.debug;
      enableFileLogging = false; // Don't clutter storage in debug
    } else if (kProfileMode) {
      logLevel = Level.info;
      enableFileLogging = true;
    } else {
      // kReleaseMode
      logLevel = Level.warning;
      enableFileLogging = true;
    }

    // Set up log directory for file output
    if (enableFileLogging) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        logDirectory =
            path.join(appDir.path, 'telegram_flutter_client', 'logs');
      } catch (e) {
        // If we can't get the directory, disable file logging
        enableFileLogging = false;
      }
    }

    // Create global context with app information
    final globalContext = LogContext(
      module: LogModule.general,
      metadata: {
        'app_version': '1.0.0',
        'build_mode':
            kDebugMode ? 'debug' : (kProfileMode ? 'profile' : 'release'),
        'platform': defaultTargetPlatform.name,
      },
    );

    // Initialize the logger
    await AppLogger.instance.initialize(
      level: logLevel,
      globalContext: globalContext,
      enableFileLogging: enableFileLogging,
      logDirectory: logDirectory,
    );

    // Log initialization success
    AppLogger.instance.info(
      'Logging system initialized',
      context: LogContext(
        module: LogModule.general,
        metadata: {
          'log_level': logLevel.name,
          'file_logging': enableFileLogging,
          'log_directory': logDirectory,
          'tdlib_log_level': LoggingConfig.tdlibLogLevel.toString(),
        },
      ),
    );
  }

  static Future<void> configureForTesting() async {
    await AppLogger.instance.initialize(
      level: Level.debug,
      enableFileLogging: false,
      globalContext: const LogContext(
        module: LogModule.general,
        metadata: {'environment': 'test'},
      ),
    );
  }

  static void shutdown() {
    AppLogger.instance.close();
  }
}
