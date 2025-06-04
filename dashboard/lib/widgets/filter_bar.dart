import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:network_logger_dashboard/blocs/network_logs_bloc.dart';
import 'package:network_logger_dashboard/blocs/network_logs_event.dart';
import 'package:network_logger_dashboard/blocs/network_logs_state.dart';
import 'package:network_logger_dashboard/models/network_log.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NetworkLogsBloc, NetworkLogsState>(
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search URLs, methods, status codes...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    context.read<NetworkLogsBloc>().add(
                          NetworkLogsEvent.filtered(
                            state.filter.copyWith(searchTerm: value),
                          ),
                        );
                  },
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: state.filter.method.isEmpty ? null : state.filter.method,
                hint: const Text('Method'),
                items: const [
                  DropdownMenuItem(value: 'GET', child: Text('GET')),
                  DropdownMenuItem(value: 'POST', child: Text('POST')),
                  DropdownMenuItem(value: 'PUT', child: Text('PUT')),
                  DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
                  DropdownMenuItem(value: 'PATCH', child: Text('PATCH')),
                ],
                onChanged: (value) {
                  context.read<NetworkLogsBloc>().add(
                        NetworkLogsEvent.filtered(
                          state.filter.copyWith(method: value ?? ''),
                        ),
                      );
                },
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: state.filter.statusCode.isEmpty ? null : state.filter.statusCode,
                hint: const Text('Status'),
                items: const [
                  DropdownMenuItem(value: '2xx', child: Text('2xx Success')),
                  DropdownMenuItem(value: '4xx', child: Text('4xx Client Error')),
                  DropdownMenuItem(value: '5xx', child: Text('5xx Server Error')),
                ],
                onChanged: (value) {
                  context.read<NetworkLogsBloc>().add(
                        NetworkLogsEvent.filtered(
                          state.filter.copyWith(statusCode: value ?? ''),
                        ),
                      );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
