import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:network_logger_dashboard/models/network_log.dart';

part 'network_logs_event.freezed.dart';

@freezed
class NetworkLogsEvent with _$NetworkLogsEvent {
  const factory NetworkLogsEvent.initialized() = NetworkLogsInitialized;
  const factory NetworkLogsEvent.received(List<dynamic> logs) = NetworkLogsReceived;
  const factory NetworkLogsEvent.filtered(NetworkLogFilter filter) = NetworkLogsFiltered;
  const factory NetworkLogsEvent.cleared() = NetworkLogsCleared;
}
