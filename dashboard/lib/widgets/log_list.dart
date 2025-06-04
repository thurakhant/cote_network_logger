import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:network_logger_dashboard/blocs/network_logs_bloc.dart';
import 'package:network_logger_dashboard/blocs/network_logs_event.dart';
import 'package:network_logger_dashboard/blocs/network_logs_state.dart';
import 'package:network_logger_dashboard/models/network_log.dart';
import 'package:intl/intl.dart';

class LogList extends StatelessWidget {
  const LogList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NetworkLogsBloc, NetworkLogsState>(
      builder: (context, state) {
        if (state.filteredLogs.isEmpty) {
          return const Center(
            child: Text('No network logs to display'),
          );
        }

        return ListView.builder(
          itemCount: state.filteredLogs.length,
          itemBuilder: (context, index) {
            final log = state.filteredLogs[index];
            return _LogItem(log: log);
          },
        );
      },
    );
  }
}

class _LogItem extends StatelessWidget {
  final NetworkLog log;

  const _LogItem({required this.log});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeFormat = DateFormat('HH:mm:ss');

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ExpansionTile(
        title: Row(
          children: [
            _MethodChip(method: log.method),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                log.url,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
        subtitle: Row(
          children: [
            _StatusChip(statusCode: log.statusCode),
            const SizedBox(width: 8),
            Text(
              timeFormat.format(log.timestamp),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (log.requestBody != null) ...[
                  Text('Request Body', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _JsonViewer(json: log.requestBody!),
                  const SizedBox(height: 16),
                ],
                if (log.responseBody != null) ...[
                  Text('Response Body', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _JsonViewer(json: log.responseBody!),
                  const SizedBox(height: 16),
                ],
                if (log.error != null) ...[
                  Text('Error', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    log.error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String method;

  const _MethodChip({required this.method});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color backgroundColor;
    Color textColor;

    switch (method.toUpperCase()) {
      case 'GET':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade900;
        break;
      case 'POST':
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade900;
        break;
      case 'PUT':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade900;
        break;
      case 'DELETE':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade900;
        break;
      case 'PATCH':
        backgroundColor = Colors.purple.shade100;
        textColor = Colors.purple.shade900;
        break;
      default:
        backgroundColor = theme.colorScheme.surfaceVariant;
        textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        method.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final int statusCode;

  const _StatusChip({required this.statusCode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color backgroundColor;
    Color textColor;

    if (statusCode >= 200 && statusCode < 300) {
      backgroundColor = Colors.green.shade100;
      textColor = Colors.green.shade900;
    } else if (statusCode >= 400 && statusCode < 500) {
      backgroundColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
    } else if (statusCode >= 500) {
      backgroundColor = Colors.red.shade100;
      textColor = Colors.red.shade900;
    } else {
      backgroundColor = theme.colorScheme.surfaceVariant;
      textColor = theme.colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusCode.toString(),
        style: theme.textTheme.bodySmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _JsonViewer extends StatelessWidget {
  final String json;

  const _JsonViewer({required this.json});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: SelectableText(
        json,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
            ),
      ),
    );
  }
}
