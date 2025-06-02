import 'dart:collection';
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

  final Queue<Map<String, dynamic>> _logs = Queue<Map<String, dynamic>>();
  final Map<String, NetworkLogRequest> _requests = {};
  final Map<String, NetworkLogResponse> _responses = {};

  /// Add a new log entry. Removes oldest if limit exceeded.
  ///
  /// [logEntry] The log data to store
  void addLog(Map<String, dynamic> logEntry) {
    if (!NetworkLoggerConfig.isEnabled) return;

    // Ensure unique log ID
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
    while (_logs.length > NetworkLoggerConfig.maxLogEntries) {
      _logs.removeFirst();
    }

    // Broadcast to WebSocket clients for real-time dashboard updates
    NetworkLogWebServer.instance.broadcastLog(logEntry);
  }

  /// Get all current log entries.
  ///
  /// Returns an empty list if not in debug mode or staging environment.
  List<Map<String, dynamic>> getLogs() {
    if (!NetworkLoggerConfig.isEnabled) return [];
    return _logs.toList();
  }

  /// Clear all stored logs.
  ///
  /// Only clears logs in debug mode or staging environment.
  void clearLogs() {
    if (!NetworkLoggerConfig.isEnabled) return;
    _logs.clear();
  }

  /// Get the current number of stored logs.
  int get logCount => NetworkLoggerConfig.isEnabled ? _logs.length : 0;

  /// Add a request to the store
  void addRequest(NetworkLogRequest request) {
    _requests[request.url] = request;
    _cleanup();
  }

  /// Add a response to the store
  void addResponse(NetworkLogResponse response) {
    _responses[response.requestId] = response;
    _cleanup();
  }

  /// Get a request by URL
  NetworkLogRequest? getRequest(String url) => _requests[url];

  /// Get a response by request ID
  NetworkLogResponse? getResponse(String requestId) => _responses[requestId];

  /// Get all requests
  List<NetworkLogRequest> get requests => _requests.values.toList();

  /// Get all responses
  List<NetworkLogResponse> get responses => _responses.values.toList();

  /// Clear all logs
  void clear() {
    _requests.clear();
    _responses.clear();
  }

  void _cleanup() {
    if (_requests.length > NetworkLoggerConfig.maxLogEntries) {
      final oldestRequests = _requests.values.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final requestsToRemove = oldestRequests.take(_requests.length - NetworkLoggerConfig.maxLogEntries).map((r) => r.url);
      for (final url in requestsToRemove) {
        _requests.remove(url);
      }
    }

    if (_responses.length > NetworkLoggerConfig.maxLogEntries) {
      final oldestResponses = _responses.values.toList()..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final responsesToRemove = oldestResponses.take(_responses.length - NetworkLoggerConfig.maxLogEntries).map((r) => r.requestId);
      for (final requestId in responsesToRemove) {
        _responses.remove(requestId);
      }
    }
  }
}
