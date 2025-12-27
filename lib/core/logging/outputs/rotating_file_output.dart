import 'dart:io';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

class RotatingFileOutput extends LogOutput {
  final String logDirectory;
  final int maxFiles;
  final int maxFileSizeBytes;
  final String filePrefix;

  File? _currentFile;
  int _currentFileSize = 0;

  RotatingFileOutput({
    required this.logDirectory,
    this.maxFiles = 7,
    this.maxFileSizeBytes = 10 * 1024 * 1024, // 10 MB
    this.filePrefix = 'app',
  });

  @override
  Future<void> init() async {
    await super.init();
    _ensureLogDirectory();
    _rotateLogsIfNeeded();
  }

  @override
  void output(OutputEvent event) {
    _ensureCurrentFile();

    for (final line in event.lines) {
      _writeToFile('$line\n');
    }
  }

  void _ensureLogDirectory() {
    final dir = Directory(logDirectory);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }

  void _ensureCurrentFile() {
    if (_currentFile == null || _shouldRotateFile()) {
      _rotateFile();
    }
  }

  bool _shouldRotateFile() {
    return _currentFile != null && _currentFileSize > maxFileSizeBytes;
  }

  void _rotateFile() {
    // Close current file
    _currentFile = null;
    _currentFileSize = 0;

    // Create new file
    final timestamp = DateTime.now().toIso8601String().split('T')[0];
    final fileName = '${filePrefix}_$timestamp.log';
    _currentFile = File(path.join(logDirectory, fileName));

    // Clean up old files
    _cleanupOldFiles();
  }

  void _rotateLogsIfNeeded() {
    final dir = Directory(logDirectory);
    if (!dir.existsSync()) return;

    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => path.basename(file.path).startsWith(filePrefix))
        .toList();

    if (files.length >= maxFiles) {
      files.sort(
        (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
      );

      for (int i = 0; i < files.length - maxFiles + 1; i++) {
        try {
          files[i].deleteSync();
        } catch (e) {
          // Ignore deletion errors
        }
      }
    }
  }

  void _cleanupOldFiles() {
    try {
      final dir = Directory(logDirectory);
      if (!dir.existsSync()) return;

      final files = dir
          .listSync()
          .whereType<File>()
          .where((file) => path.basename(file.path).startsWith(filePrefix))
          .toList();

      if (files.length > maxFiles) {
        files.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
        );

        for (int i = 0; i < files.length - maxFiles; i++) {
          try {
            files[i].deleteSync();
          } catch (e) {
            // Ignore deletion errors
          }
        }
      }
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  void _writeToFile(String content) {
    try {
      if (_currentFile != null) {
        _currentFile!.writeAsStringSync(content, mode: FileMode.append);
        _currentFileSize += content.length;
      }
    } catch (e) {
      // If writing fails, we can't do much about it
      // The console output should still work
    }
  }

  @override
  Future<void> destroy() async {
    _currentFile = null;
    await super.destroy();
  }
}
