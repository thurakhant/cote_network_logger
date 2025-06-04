import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:network_logger_dashboard/blocs/network_logs_bloc.dart';
import 'package:network_logger_dashboard/blocs/network_logs_event.dart';
import 'package:network_logger_dashboard/blocs/network_logs_state.dart';
import 'package:network_logger_dashboard/screens/dashboard_screen.dart';
import 'package:network_logger_dashboard/services/websocket_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (context) => WebSocketService(),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => NetworkLogsBloc(
              webSocketService: context.read<WebSocketService>(),
            )..add(const NetworkLogsEvent.initialized()),
          ),
        ],
        child: MaterialApp(
          title: 'Network Logger Dashboard',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: const DashboardScreen(),
        ),
      ),
    );
  }
}
