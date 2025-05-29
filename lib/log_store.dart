import 'dart:collection';
import 'package:flutter/foundation.dart';

/// Manages network logs in memory for the developer dashboard.
/// Automatically limits storage and only works in debug mode.
class NetworkLogStore {
  NetworkLogStore._internal();
  static final NetworkLogStore _instance = NetworkLogStore._internal();

  /// Returns the singleton instance of NetworkLogStore.
  static NetworkLogStore get instance => _instance;

  static const int _maxLogEntries = 200;
  final Queue<Map<String, dynamic>> _logs = Queue<Map<String, dynamic>>();

  /// Adds a new log entry. Removes old entries if limit exceeded.
  ///
  /// [logEntry] The log data to store
  void addLog(Map<String, dynamic> logEntry) {
    if (!kDebugMode) return;

    // Handle duplicate IDs
    final String originalId = logEntry['id']?.toString() ?? '';
    String uniqueId = originalId;
    int suffix = 0;

    while (_logs.any((log) => log['id'] == uniqueId)) {
      suffix++;
      uniqueId = '${originalId}_dup$suffix';
    }

    if (suffix > 0) {
      logEntry = Map<String, dynamic>.from(logEntry);
      logEntry['id'] = uniqueId;
    }

    _logs.addLast(logEntry);

    // Remove old entries if we exceed the limit
    while (_logs.length > _maxLogEntries) {
      _logs.removeFirst();
    }
  }

  /// Returns all current log entries.
  ///
  /// Returns an empty list if not in debug mode.
  List<Map<String, dynamic>> getLogs() {
    if (!kDebugMode) return [];
    return _logs.toList();
  }

  /// Clears all stored logs.
  ///
  /// Only clears logs in debug mode.
  void clearLogs() {
    if (!kDebugMode) return;
    _logs.clear();
  }

  /// Returns the current number of stored logs.
  int get logCount => kDebugMode ? _logs.length : 0;
}
