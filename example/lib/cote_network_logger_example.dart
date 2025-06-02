import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:cote_network_logger/cote_network_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start the network logger server
  final serverStarted = await startNetworkLogServer();
  if (serverStarted) {
    debugPrint('✅ Network Logger Dashboard: ${getNetworkLogDashboardUrl()}');
  }

  runApp(const NetworkLoggerExampleApp());
}

class NetworkLoggerExampleApp extends StatelessWidget {
  const NetworkLoggerExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cote Network Logger Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ApiService _apiService;
  bool _isLoading = false;
  String _lastResponse = '';

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardUrl = getNetworkLogDashboardUrl();
    final currentFlavor = NetworkLoggerConfig.currentFlavor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Logger Demo'),
        actions: [
          // Environment indicator
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getFlavorColor(currentFlavor).withAlpha(26),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _getFlavorColor(currentFlavor),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getFlavorIcon(currentFlavor),
                  size: 16,
                  color: _getFlavorColor(currentFlavor),
                ),
                const SizedBox(width: 4),
                Text(
                  currentFlavor,
                  style: TextStyle(
                    color: _getFlavorColor(currentFlavor),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dashboard info card
              if (dashboardUrl != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.dashboard, color: Colors.blue.shade600),
                            const SizedBox(width: 8),
                            const Text(
                              'Network Logger Dashboard',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            dashboardUrl,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Open this URL in your browser to see network requests in real-time',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Test requests section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Network Requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildRequestButton(
                        'GET Request',
                        'Fetch posts from JSONPlaceholder',
                        Icons.download,
                        Colors.green,
                        _apiService.getPosts,
                      ),
                      const SizedBox(height: 12),
                      _buildRequestButton(
                        'POST Request',
                        'Create a new post',
                        Icons.upload,
                        Colors.orange,
                        _apiService.createPost,
                      ),
                      const SizedBox(height: 12),
                      _buildRequestButton(
                        'Error Request',
                        'Trigger a 404 error',
                        Icons.error,
                        Colors.red,
                        _apiService.triggerError,
                      ),
                      const SizedBox(height: 12),
                      _buildRequestButton(
                        'Multiple Requests',
                        'Send 3 requests concurrently',
                        Icons.burst_mode,
                        Colors.teal,
                        _sendMultipleRequests,
                      ),
                      const SizedBox(height: 12),
                      _buildRequestButton(
                        'Batch Requests',
                        'Send 5 requests with delay',
                        Icons.timer,
                        Colors.purple,
                        _sendBatchRequests,
                      ),
                    ],
                  ),
                ),
              ),

              // Response display
              if (_lastResponse.isNotEmpty) ...[
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Last Response',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Text(
                            _lastResponse,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              if (_isLoading) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequestButton(
    String title,
    String description,
    IconData icon,
    Color color,
    Future<void> Function() onPressed,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withAlpha(26),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(description),
      trailing: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.arrow_forward_ios, color: Colors.grey.shade400),
      onTap: _isLoading ? null : () => _makeRequest(onPressed),
    );
  }

  Future<void> _makeRequest(Future<void> Function() requestFunction) async {
    setState(() {
      _isLoading = true;
      _lastResponse = '';
    });

    try {
      await requestFunction();
      setState(() {
        _lastResponse = 'Request completed successfully! Check the dashboard to see the network details.';
      });
    } catch (e) {
      setState(() {
        _lastResponse = 'Error: $e\nCheck the dashboard to see error details!';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMultipleRequests() async {
    setState(() {
      _isLoading = true;
      _lastResponse = '';
    });

    try {
      // Send multiple requests concurrently
      await Future.wait([
        _apiService.getPosts(),
        _apiService.createPost(),
        _apiService.getPosts(),
      ]);
      setState(() {
        _lastResponse = 'Multiple requests completed successfully! Check the dashboard to see concurrent requests.';
      });
    } catch (e) {
      setState(() {
        _lastResponse = 'Error in multiple requests: $e\nCheck the dashboard to see error details!';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendBatchRequests() async {
    setState(() {
      _isLoading = true;
      _lastResponse = '';
    });

    try {
      // Send requests with a delay between each
      for (var i = 0; i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _apiService.getPosts();
      }
      setState(() {
        _lastResponse = 'Batch requests completed successfully! Check the dashboard to see sequential requests.';
      });
    } catch (e) {
      setState(() {
        _lastResponse = 'Error in batch requests: $e\nCheck the dashboard to see error details!';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Color _getFlavorColor(String flavor) {
    switch (flavor.toLowerCase()) {
      case 'staging':
        return Colors.orange;
      case 'debug':
        return Colors.blue;
      case 'production':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getFlavorIcon(String flavor) {
    switch (flavor.toLowerCase()) {
      case 'staging':
        return Icons.storage;
      case 'debug':
        return Icons.bug_report;
      case 'production':
        return Icons.security;
      default:
        return Icons.info;
    }
  }
}

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://jsonplaceholder.typicode.com',
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 3),
      ),
    );

    // Add the network logger interceptor
    _dio.interceptors.add(const CoteNetworkLogger());
  }

  Future<void> getPosts() async {
    final response = await _dio.get('/posts');
    debugPrint('GET Posts: ${response.statusCode}');
  }

  Future<void> createPost() async {
    final response = await _dio.post(
      '/posts',
      data: {
        'title': 'Test Post',
        'body': 'This is a test post created via Network Logger example app.',
        'userId': 1,
      },
    );
    debugPrint('POST Create: ${response.statusCode}');
  }

  Future<void> triggerError() async {
    try {
      await _dio.get('/posts/nonexistent-endpoint-404');
    } catch (e) {
      debugPrint('Error Request: $e');
      rethrow;
    }
  }
}
