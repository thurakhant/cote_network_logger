import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'log_store.dart';
import 'web_server.dart';

/// Dio interceptor that captures HTTP requests and responses for the network logger dashboard.
/// Provides manual logging and dashboard server control. Only works in debug mode.
class CoteNetworkLogger extends Interceptor {
  const CoteNetworkLogger();

  /// Start the web dashboard server for real-time monitoring.
  /// Returns true if the server started successfully.
  Future<bool> startDashboard() async {
    return await NetworkLogWebServer.instance.start();
  }

  /// Get the dashboard URL.
  String get dashboardUrl => NetworkLogWebServer.instance.dashboardUrl;

  /// Check if the dashboard server is running.
  bool get isDashboardRunning => NetworkLogWebServer.instance.isRunning;

  /// Check if the web server is supported on this platform.
  bool get isWebServerSupported => NetworkLogWebServer.isPlatformSupported;

  /// Manually log an HTTP request (for non-Dio requests).
  void logRequest({
    required String id,
    required String url,
    required String method,
    Map<String, dynamic>? headers,
    dynamic requestBody,
  }) {
    if (!kDebugMode) return;
    final logEntry = {
      'id': id,
      'type': 'request',
      'timestamp': DateTime.now().toIso8601String(),
      'method': method.toUpperCase(),
      'url': url,
      'headers': headers ?? {},
      'requestBody': _sanitizeBody(requestBody),
    };
    NetworkLogStore.instance.addLog(logEntry);
  }

  /// Manually log an HTTP response (for non-Dio responses).
  void logResponse({
    required String id,
    required String url,
    required String method,
    required int statusCode,
    Map<String, dynamic>? headers,
    dynamic responseBody,
  }) {
    if (!kDebugMode) return;
    final logEntry = {
      'id': id,
      'type': 'response',
      'timestamp': DateTime.now().toIso8601String(),
      'method': method.toUpperCase(),
      'url': url,
      'statusCode': statusCode,
      'headers': headers ?? {},
      'responseBody': _sanitizeBody(responseBody),
      'responseSize': _calculateResponseSize(responseBody),
    };
    NetworkLogStore.instance.addLog(logEntry);
  }

  /// Manually log an HTTP error (for non-Dio errors).
  void logError({
    required String id,
    required String url,
    required String method,
    required String error,
    String? stackTrace,
    int? statusCode,
  }) {
    if (!kDebugMode) return;
    final logEntry = {
      'id': id,
      'type': 'error',
      'timestamp': DateTime.now().toIso8601String(),
      'method': method.toUpperCase(),
      'url': url,
      'errorMessage': error,
      'stackTrace': stackTrace,
      'statusCode': statusCode,
    };
    NetworkLogStore.instance.addLog(logEntry);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      final logEntry = _createRequestLog(options);
      NetworkLogStore.instance.addLog(logEntry);
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      final logEntry = _createResponseLog(response);
      NetworkLogStore.instance.addLog(logEntry);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      final logEntry = _createErrorLog(err);
      NetworkLogStore.instance.addLog(logEntry);
    }
    handler.next(err);
  }

  Map<String, dynamic> _createRequestLog(RequestOptions options) {
    return {
      'id': _generateLogId(),
      'type': 'request',
      'timestamp': DateTime.now().toIso8601String(),
      'method': options.method,
      'url': options.uri.toString(),
      'headers': options.headers,
      'queryParameters': options.queryParameters,
      'requestBody': _sanitizeBody(options.data),
      'contentType': options.contentType,
    };
  }

  Map<String, dynamic> _createResponseLog(Response response) {
    return {
      'id': _generateLogId(),
      'type': 'response',
      'timestamp': DateTime.now().toIso8601String(),
      'method': response.requestOptions.method,
      'url': response.requestOptions.uri.toString(),
      'statusCode': response.statusCode,
      'statusMessage': response.statusMessage,
      'headers': response.headers.map,
      'responseBody': _sanitizeBody(response.data),
      'responseSize': _calculateResponseSize(response.data),
    };
  }

  Map<String, dynamic> _createErrorLog(DioException error) {
    return {
      'id': _generateLogId(),
      'type': 'error',
      'timestamp': DateTime.now().toIso8601String(),
      'method': error.requestOptions.method,
      'url': error.requestOptions.uri.toString(),
      'errorType': error.type.toString(),
      'errorMessage': error.message,
      'statusCode': error.response?.statusCode,
      'statusMessage': error.response?.statusMessage,
      'responseBody': error.response?.data != null ? _sanitizeBody(error.response!.data) : null,
    };
  }

  /// Cleans up body data and limits size to prevent memory issues.
  dynamic _sanitizeBody(dynamic data) {
    if (data == null) return null;

    try {
      String stringData;
      if (data is String) {
        stringData = data;
      } else if (data is Map || data is List) {
        stringData = jsonEncode(data);
      } else {
        stringData = data.toString();
      }

      // Limit to 10KB
      const int maxBodySize = 10240;
      if (stringData.length > maxBodySize) {
        return '${stringData.substring(0, maxBodySize)}... [TRUNCATED]';
      }

      return stringData;
    } catch (e) {
      return '[UNPARSEABLE_DATA: ${data.runtimeType}]';
    }
  }

  int _calculateResponseSize(dynamic data) {
    if (data == null) return 0;
    try {
      if (data is String) {
        return data.length;
      } else if (data is List<int>) {
        return data.length;
      } else {
        return jsonEncode(data).length;
      }
    } catch (e) {
      return 0;
    }
  }

  String _generateLogId() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = (DateTime.now().millisecondsSinceEpoch * 31) % 10000;
    return '${timestamp}_$random';
  }
}
