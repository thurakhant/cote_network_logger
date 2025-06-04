import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:network_logger_dashboard/blocs/network_logs_bloc.dart';
import 'package:network_logger_dashboard/blocs/network_logs_event.dart';
import 'package:network_logger_dashboard/blocs/network_logs_state.dart';
import 'package:network_logger_dashboard/widgets/log_list.dart';
import 'package:network_logger_dashboard/widgets/filter_bar.dart';
import 'package:network_logger_dashboard/widgets/stats_bar.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Logger Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // TODO: Implement refresh
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              context.read<NetworkLogsBloc>().add(const NetworkLogsEvent.cleared());
            },
          ),
        ],
      ),
      body: Column(
        children: [
          const StatsBar(),
          const FilterBar(),
          const Expanded(
            child: LogList(),
          ),
        ],
      ),
    );
  }
}
