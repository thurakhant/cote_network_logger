import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:network_logger_dashboard/blocs/network_logs_bloc.dart';
import 'package:network_logger_dashboard/blocs/network_logs_event.dart';
import 'package:network_logger_dashboard/blocs/network_logs_state.dart';

class StatsBar extends StatelessWidget {
  const StatsBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NetworkLogsBloc, NetworkLogsState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceVariant,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(
                label: 'Total Requests',
                value: state.logs.length.toString(),
                icon: Icons.list_alt,
              ),
              _StatItem(
                label: 'Filtered',
                value: state.filteredLogs.length.toString(),
                icon: Icons.filter_list,
              ),
              _StatItem(
                label: 'Errors',
                value: state.logs.where((log) => log.statusCode >= 400).length.toString(),
                icon: Icons.error_outline,
                color: Colors.red,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color ?? Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: color ?? Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
