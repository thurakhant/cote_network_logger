import 'package:cote_network_logger/cote_network_logger.dart';

void main() async {
  print('🚀 Testing Flutter Web Dashboard Integration...');

  // Start the network logger server
  final serverStarted = await startNetworkLogServer();

  if (serverStarted) {
    print('✅ Server started successfully!');
    print('📱 Dashboard URL: ${getNetworkLogDashboardUrl()}');
    print('');
    print('📋 What to do next:');
    print('1. Open the dashboard URL in your browser');
    print('2. You should see the Flutter Web dashboard (not HTML/JS)');
    print('3. Make some HTTP requests to test the logger');
    print('');
    print('Press Ctrl+C to stop the server');

    // Keep the server running
    await Future.delayed(Duration(minutes: 10));
  } else {
    print('❌ Failed to start server');
  }
}
