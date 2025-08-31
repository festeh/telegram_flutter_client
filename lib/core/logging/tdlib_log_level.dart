/// TDLib native logging verbosity levels
/// 
/// Controls how much logging output the TDLib C++ library produces.
/// Lower values = less logging, higher values = more verbose logging.
enum TdLibLogLevel {
  /// 0: Only fatal errors - minimal logging (recommended for production)
  fatal(0, 'Fatal errors only'),
  
  /// 1: Errors - shows error messages
  error(1, 'Errors'),
  
  /// 2: Warnings and debug warnings
  warning(2, 'Warnings and debug warnings'),
  
  /// 3: Informational messages
  info(3, 'Informational'),
  
  /// 4: Debug messages
  debug(4, 'Debug'),
  
  /// 5: Verbose debug (TDLib default) - very chatty
  verbose(5, 'Verbose debug');

  const TdLibLogLevel(this.level, this.description);

  /// The numeric level to send to TDLib
  final int level;
  
  /// Human-readable description of this log level
  final String description;

  /// Get the recommended log level based on build mode
  static TdLibLogLevel getDefault(bool isDebugMode, bool isReleaseMode) {
    if (isDebugMode) {
      return TdLibLogLevel.warning; // Show some info for debugging
    } else if (isReleaseMode) {
      return TdLibLogLevel.fatal; // Minimal logging in production
    } else {
      return TdLibLogLevel.error; // Profile mode - show errors
    }
  }

  @override
  String toString() => '$name (level $level): $description';
}