import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:network_logger_dashboard/models/network_log.dart';
import 'package:network_logger_dashboard/services/websocket_service.dart';

// part 'network_logs_bloc.freezed.dart';
import 'network_logs_event.dart';
import 'network_logs_state.dart';

class NetworkLogsBloc extends Bloc<NetworkLogsEvent, NetworkLogsState> {
  final WebSocketService webSocketService;

  NetworkLogsBloc({required this.webSocketService}) : super(const NetworkLogsState()) {
    on<NetworkLogsInitialized>(_onInitialized);
    on<NetworkLogsReceived>(_onLogsReceived);
    on<NetworkLogsFiltered>(_onLogsFiltered);
    on<NetworkLogsCleared>(_onLogsCleared);
  }

  void _onInitialized(NetworkLogsInitialized event, Emitter<NetworkLogsState> emit) {
    webSocketService.connect();
    webSocketService.messages.listen((message) {
      if (message['type'] == 'init') {
        add(NetworkLogsEvent.received(message['logs'] as List<dynamic>));
      } else if (message['type'] == 'log') {
        add(NetworkLogsEvent.received([message['log']]));
      }
    });
  }

  void _onLogsReceived(NetworkLogsReceived event, Emitter<NetworkLogsState> emit) {
    final newLogs = event.logs.map((log) => NetworkLog.fromJson(log as Map<String, dynamic>)).toList();
    final allLogs = [...state.logs, ...newLogs];
    emit(state.copyWith(
      logs: allLogs,
      filteredLogs: _applyFilters(allLogs, state.filter),
    ));
  }

  void _onLogsFiltered(NetworkLogsFiltered event, Emitter<NetworkLogsState> emit) {
    emit(state.copyWith(
      filter: event.filter,
      filteredLogs: _applyFilters(state.logs, event.filter),
    ));
  }

  void _onLogsCleared(NetworkLogsCleared event, Emitter<NetworkLogsState> emit) {
    emit(state.copyWith(
      logs: [],
      filteredLogs: [],
    ));
  }

  List<NetworkLog> _applyFilters(List<NetworkLog> logs, NetworkLogFilter filter) {
    return logs.where((log) {
      if (filter.searchTerm.isNotEmpty) {
        final searchLower = filter.searchTerm.toLowerCase();
        if (!log.url.toLowerCase().contains(searchLower) && !log.method.toLowerCase().contains(searchLower)) {
          return false;
        }
      }

      if (filter.method.isNotEmpty && log.method != filter.method) {
        return false;
      }

      if (filter.statusCode.isNotEmpty) {
        final statusCode = log.statusCode.toString();
        if (filter.statusCode == '2xx' && !statusCode.startsWith('2')) return false;
        if (filter.statusCode == '4xx' && !statusCode.startsWith('4')) return false;
        if (filter.statusCode == '5xx' && !statusCode.startsWith('5')) return false;
      }

      return true;
    }).toList();
  }
}
