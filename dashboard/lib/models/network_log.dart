import 'package:freezed_annotation/freezed_annotation.dart';

part 'network_log.freezed.dart';
part 'network_log.g.dart';

@freezed
class NetworkLog with _$NetworkLog {
  const factory NetworkLog({
    required String method,
    required String url,
    required int statusCode,
    required DateTime timestamp,
    String? requestBody,
    String? responseBody,
    String? error,
  }) = _NetworkLog;

  factory NetworkLog.fromJson(Map<String, dynamic> json) => _$NetworkLogFromJson(json);
}

@freezed
class NetworkLogFilter with _$NetworkLogFilter {
  const factory NetworkLogFilter({
    @Default('') String searchTerm,
    @Default('') String method,
    @Default('') String statusCode,
  }) = _NetworkLogFilter;
}
