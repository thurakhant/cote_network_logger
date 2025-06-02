import 'package:dio/dio.dart';
import 'cote_network_logger.dart';

/// A Dio interceptor that logs HTTP requests and responses
class CoteNetworkLogger extends Interceptor {
  const CoteNetworkLogger();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!NetworkLoggerConfig.isEnabled) {
      handler.next(options);
      return;
    }

    final request = NetworkLogRequest(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      method: options.method,
      url: options.uri.toString(),
      headers: options.headers,
      body: options.data,
      timestamp: DateTime.now(),
    );

    NetworkLogStore.instance.addRequest(request);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (!NetworkLoggerConfig.isEnabled) {
      handler.next(response);
      return;
    }

    final request = NetworkLogStore.instance.getRequest(response.requestOptions.uri.toString());
    if (request != null) {
      final logResponse = NetworkLogResponse(
        requestId: request.id,
        statusCode: response.statusCode,
        headers: response.headers.map,
        body: response.data,
        timestamp: DateTime.now(),
      );

      NetworkLogStore.instance.addResponse(logResponse);
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (!NetworkLoggerConfig.isEnabled) {
      handler.next(err);
      return;
    }

    final request = NetworkLogStore.instance.getRequest(err.requestOptions.uri.toString());
    if (request != null) {
      final errorResponse = NetworkLogResponse(
        requestId: request.id,
        statusCode: err.response?.statusCode,
        headers: err.response?.headers.map,
        body: err.response?.data,
        error: err.message,
        timestamp: DateTime.now(),
      );

      NetworkLogStore.instance.addResponse(errorResponse);
    }

    handler.next(err);
  }
}
