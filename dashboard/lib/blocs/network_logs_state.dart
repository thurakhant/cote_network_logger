import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:network_logger_dashboard/models/network_log.dart';

part 'network_logs_state.freezed.dart';

@freezed
class NetworkLogsState with _$NetworkLogsState {
  const factory NetworkLogsState({
    @Default([]) List<NetworkLog> logs,
    @Default([]) List<NetworkLog> filteredLogs,
    @Default(NetworkLogFilter()) NetworkLogFilter filter,
  }) = _NetworkLogsState;
}
