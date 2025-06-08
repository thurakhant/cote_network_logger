import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'cote_network_logger.dart';

/// Represents a network request log entry
class NetworkLogRequest {
  final String id;
  final String method;
  final String url;
  final Map<String, dynamic>? headers;
  final dynamic body;
  final DateTime timestamp;

  NetworkLogRequest({
    required this.id,
    required this.method,
    required this.url,
    this.headers,
    this.body,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'method': method,
        'url': url,
        'headers': headers,
        'body': body,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Represents a network response log entry
class NetworkLogResponse {
  final String requestId;
  final int? statusCode;
  final Map<String, dynamic>? headers;
  final dynamic body;
  final String? error;
  final DateTime timestamp;

  NetworkLogResponse({
    required this.requestId,
    this.statusCode,
    this.headers,
    this.body,
    this.error,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'requestId': requestId,
        'statusCode': statusCode,
        'headers': headers,
        'body': body,
        'error': error,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Stores network logs in memory for the developer dashboard.
/// Only works in debug mode or staging environment and limits storage to recent entries.
class NetworkLogStore {
  NetworkLogStore._internal();
  static final NetworkLogStore _instance = NetworkLogStore._internal();

  /// Singleton instance
  static NetworkLogStore get instance => _instance;

  final Map<String, Map<String, dynamic>> _logs = {};
  final Queue<String> _logOrder = Queue<String>();

  /// Add or update a log entry for a transaction.
  void upsertLog(String transactionId, Map<String, dynamic> logUpdate) {
    if (!NetworkLoggerConfig.isEnabled) {
      return;
    }
    try {
      final existing = _logs[transactionId] ?? {};
      final merged = {
        ...existing,
        ...logUpdate,
        'transactionId': transactionId,
      };
      _logs[transactionId] = merged;
      if (!_logOrder.contains(transactionId)) {
        _logOrder.addLast(transactionId);
      }
      // Remove old entries if we exceed the limit
      while (_logOrder.length > NetworkLoggerConfig.maxLogEntries) {
        final removedId = _logOrder.removeFirst();
        _logs.remove(removedId);
      }
      NetworkLogWebServer.instance.broadcastLog(merged);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ NetworkLogStore: Failed to upsert log: $e');
    }
  }

  /// Get all current log entries, most recent first.
  List<Map<String, dynamic>> getLogs() {
    if (!NetworkLoggerConfig.isEnabled) {
      return [];
    }
    return _logOrder.toList().reversed.map((id) => _logs[id]!).toList();
  }

  /// Clear all stored logs.
  void clearLogs() {
    if (!NetworkLoggerConfig.isEnabled) {
      return;
    }
    _logs.clear();
    _logOrder.clear();
  }

  int get logCount => NetworkLoggerConfig.isEnabled ? _logs.length : 0;

  /// Add a request to the store
  void addRequest(NetworkLogRequest request) {
    try {
      _logs[request.id] = request.toJson();
      _logOrder.addLast(request.id);
      _cleanup();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ NetworkLogStore: Failed to add request: $e');
    }
  }

  /// Add a response to the store
  void addResponse(NetworkLogResponse response) {
    try {
      _logs[response.requestId] = response.toJson();
      _logOrder.addLast(response.requestId);
      _cleanup();
    } catch (e) {
      if (kDebugMode) debugPrint('❌ NetworkLogStore: Failed to add response: $e');
    }
  }

  /// Get a request by ID
  Map<String, dynamic>? getRequest(String id) => _logs[id];

  /// Get a response by request ID
  Map<String, dynamic>? getResponse(String requestId) => _logs[requestId];

  /// Clear all logs
  void clear() {
    _logs.clear();
    _logOrder.clear();
  }

  void _cleanup() {
    try {
      if (_logs.length > NetworkLoggerConfig.maxLogEntries) {
        final oldestIds = _logOrder.toList()..sort((a, b) => a.compareTo(b));
        final idsToRemove = oldestIds.take(_logs.length - NetworkLoggerConfig.maxLogEntries).toList();
        for (final id in idsToRemove) {
          _logs.remove(id);
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ NetworkLogStore: Error during cleanup: $e');
    }
  }
}
