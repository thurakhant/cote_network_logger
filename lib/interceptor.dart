import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'cote_network_logger.dart';

String _generateTransactionId(RequestOptions options) {
  // Use a combination of method, url, and a random string for uniqueness
  final rand = Random().nextInt(1 << 32);
  return '${options.method}_${options.uri}_${DateTime.now().millisecondsSinceEpoch}_$rand';
}

/// A Dio interceptor that logs HTTP requests and responses
class CoteNetworkLogger extends Interceptor {
  const CoteNetworkLogger();

  // Map to track transactionId for each request
  static final Map<RequestOptions, String> _requestTransactionIds = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!NetworkLoggerConfig.isEnabled) {
      debugPrint('⚠️ CoteNetworkLogger: Logger is disabled');
      handler.next(options);
      return;
    }
    try {
      final transactionId = _generateTransactionId(options);
      _requestTransactionIds[options] = transactionId;
      NetworkLogStore.instance.upsertLog(transactionId, {
        'transactionId': transactionId,
        'type': 'request',
        'method': options.method,
        'url': options.uri.toString(),
        'headers': options.headers,
        'body': options.data,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'pending',
      });
      debugPrint('✅ CoteNetworkLogger: Intercepted request: ${options.uri} (transactionId: $transactionId)');
      handler.next(options);
    } catch (e) {
      debugPrint('❌ CoteNetworkLogger: Failed to log request: $e');
      handler.next(options);
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!NetworkLoggerConfig.isEnabled) {
      debugPrint('⚠️ CoteNetworkLogger: Logger is disabled');
      handler.next(response);
      return;
    }
    try {
      final transactionId = _requestTransactionIds.remove(response.requestOptions) ?? _generateTransactionId(response.requestOptions);
      NetworkLogStore.instance.upsertLog(transactionId, {
        'transactionId': transactionId,
        'type': 'response',
        'method': response.requestOptions.method,
        'url': response.requestOptions.uri.toString(),
        'statusCode': response.statusCode,
        'headers': response.headers.map,
        'body': response.data,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'completed',
      });
      debugPrint('✅ CoteNetworkLogger: Intercepted response: ${response.statusCode} for ${response.requestOptions.uri} (transactionId: $transactionId)');
      handler.next(response);
    } catch (e) {
      debugPrint('❌ CoteNetworkLogger: Failed to log response: $e');
      handler.next(response);
    }
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!NetworkLoggerConfig.isEnabled) {
      debugPrint('⚠️ CoteNetworkLogger: Logger is disabled');
      handler.next(err);
      return;
    }
    try {
      final transactionId = _requestTransactionIds.remove(err.requestOptions) ?? _generateTransactionId(err.requestOptions);
      NetworkLogStore.instance.upsertLog(transactionId, {
        'transactionId': transactionId,
        'type': 'error',
        'method': err.requestOptions.method,
        'url': err.requestOptions.uri.toString(),
        'statusCode': err.response?.statusCode,
        'headers': err.response?.headers.map,
        'body': err.response?.data,
        'error': err.message,
        'timestamp': DateTime.now().toIso8601String(),
        'status': 'error',
      });
      debugPrint('❌ CoteNetworkLogger: Intercepted error: ${err.message} for ${err.requestOptions.uri} (transactionId: $transactionId)');
      handler.next(err);
    } catch (e) {
      debugPrint('❌ CoteNetworkLogger: Failed to log error: $e');
      handler.next(err);
    }
  }
}
