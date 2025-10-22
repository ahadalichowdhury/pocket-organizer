import 'dart:async';

import 'package:flutter/foundation.dart';

/// In-app logger that stores logs in memory for viewing
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  factory AppLogger() => _instance;
  AppLogger._internal();

  // Store logs in memory (max 500 logs)
  static final List<LogEntry> _logs = [];
  static const int _maxLogs = 500;

  // Stream controller for real-time log updates
  static final _streamController = StreamController<LogEntry>.broadcast();

  /// Get the log stream for real-time updates
  static Stream<LogEntry> get logStream => _streamController.stream;

  /// Add a log entry
  static void log(String message, {LogLevel level = LogLevel.info}) {
    final entry = LogEntry(
      message: message,
      level: level,
      timestamp: DateTime.now(),
    );

    _logs.insert(0, entry); // Insert at beginning (newest first)

    // Remove old logs if exceeding max
    if (_logs.length > _maxLogs) {
      _logs.removeRange(_maxLogs, _logs.length);
    }

    // Print to console in debug mode
    if (kDebugMode) {
      print('${entry.levelIcon} [${entry.levelName}] ${entry.message}');
    }

    // Notify stream listeners
    if (!_streamController.isClosed) {
      _streamController.add(entry);
    }
  }

  /// Get all logs
  static List<LogEntry> get logs => List.unmodifiable(_logs);

  /// Clear all logs
  static void clear() {
    _logs.clear();
    // Send a special clear signal
    if (!_streamController.isClosed) {
      _streamController.add(LogEntry(
        message: '__CLEAR__',
        level: LogLevel.debug,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Dispose the stream controller
  static void dispose() {
    _streamController.close();
  }

  // Convenience methods
  static void info(String message) => log(message, level: LogLevel.info);
  static void warning(String message) => log(message, level: LogLevel.warning);
  static void error(String message) => log(message, level: LogLevel.error);
  static void success(String message) => log(message, level: LogLevel.success);
  static void debug(String message) => log(message, level: LogLevel.debug);
}

/// Log levels
enum LogLevel {
  debug,
  info,
  warning,
  error,
  success,
}

/// Log entry model
class LogEntry {
  final String message;
  final LogLevel level;
  final DateTime timestamp;

  LogEntry({
    required this.message,
    required this.level,
    required this.timestamp,
  });

  String get levelName {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARNING';
      case LogLevel.error:
        return 'ERROR';
      case LogLevel.success:
        return 'SUCCESS';
    }
  }

  String get levelIcon {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
      case LogLevel.success:
        return '✅';
    }
  }

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final second = timestamp.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
