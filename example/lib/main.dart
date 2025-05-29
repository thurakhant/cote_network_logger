import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:cote_network_logger/cote_network_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  print('🚀 Starting Cote Network Logger...');

  // Check platform support first
  if (!isNetworkLoggerSupported()) {
    if (kIsWeb) {
      print('🌐 Web platform detected - Dashboard not available');
      print('💡 Use browser DevTools Network tab for debugging');
      print('💡 Network requests will still be logged to console');
    } else {
      print('❌ Platform not supported for dashboard');
    }
  } else {
    // Start the network logger server
    try {
      final serverStarted = await startNetworkLogServer();
      if (serverStarted) {
        print('✅ Network Logger server started successfully!');
        debugPrint('🌐 Network Logger Dashboard: http://localhost:3000');
      } else {
        print('❌ Failed to start Network Logger server');
        print('💡 This could be due to:');
        print('   - Port 3000 already in use');
        print('   - Permission issues');
      }
    } catch (e) {
      print('💥 Error starting server: $e');
    }
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
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
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
  int _requestCount = 0;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardUrl = getNetworkLogDashboardUrl();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cote Network Logger Demo'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dashboard info card
              Card(
                color: isNetworkLoggerSupported() ? Colors.blue.shade50 : Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isNetworkLoggerSupported() ? Icons.dashboard : Icons.info,
                            color: isNetworkLoggerSupported() ? Colors.blue.shade600 : Colors.orange.shade600,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isNetworkLoggerSupported() ? 'Network Logger Dashboard' : 'Platform Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isNetworkLoggerSupported() ? Colors.blue.shade600 : Colors.orange.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isNetworkLoggerSupported()) ...[
                        if (dashboardUrl != null) ...[
                          Text(
                            'Open the dashboard in your browser:',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
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
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info, color: Colors.green.shade600, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'How to test:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '1. Open the dashboard URL above in a new browser tab\n'
                                  '2. Come back here and tap the test buttons below\n'
                                  '3. Watch real-time network activity in the dashboard!',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              'Server not running (check debug console for details)',
                              style: TextStyle(color: Colors.red.shade600),
                            ),
                          ),
                        ],
                      ] else ...[
                        // Web platform or unsupported platform
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (kIsWeb) ...[
                                Row(
                                  children: [
                                    Icon(Icons.web, color: Colors.orange.shade600, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Web Platform Detected',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.orange.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dashboard not available on web due to browser security restrictions.\n'
                                  'Use Browser DevTools → Network tab for debugging instead.\n'
                                  'Network requests are still being intercepted and logged to console.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ] else ...[
                                Text(
                                  'Platform not supported for dashboard.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Stats card
              Card(
                color: Colors.grey.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStat('Requests Made', _requestCount.toString(), Icons.send),
                      _buildStat(
                        'Dashboard',
                        isNetworkLoggerSupported() ? (dashboardUrl != null ? 'Active' : 'Inactive') : (kIsWeb ? 'Web Mode' : 'Not Supported'),
                        isNetworkLoggerSupported() ? (dashboardUrl != null ? Icons.check_circle : Icons.cancel) : (kIsWeb ? Icons.web : Icons.warning),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Request buttons
              Text(
                'Test Different Request Types:',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
                'PUT Request',
                'Update an existing post',
                Icons.edit,
                Colors.blue,
                _apiService.updatePost,
              ),

              const SizedBox(height: 12),

              _buildRequestButton(
                'DELETE Request',
                'Delete a post',
                Icons.delete,
                Colors.red,
                _apiService.deletePost,
              ),

              const SizedBox(height: 12),

              _buildRequestButton(
                'Error Request',
                'Trigger a 404 error',
                Icons.error,
                Colors.purple,
                _apiService.triggerError,
              ),

              const SizedBox(height: 12),

              _buildRequestButton(
                'Multiple Requests',
                'Send 3 requests at once',
                Icons.burst_mode,
                Colors.teal,
                _sendMultipleRequests,
              ),

              const SizedBox(height: 24),

              // Response display
              if (_lastResponse.isNotEmpty) ...[
                Text(
                  'Last Response:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _lastResponse,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
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

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade600,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestButton(
    String title,
    String description,
    IconData icon,
    Color color,
    Future<void> Function() onPressed,
  ) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
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
      ),
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
        _requestCount++;
        _lastResponse = 'Request completed successfully! Check the dashboard to see the network details.';
      });
    } catch (e) {
      setState(() {
        _requestCount++;
        _lastResponse = 'Error: $e\nCheck the dashboard to see error details!';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMultipleRequests() async {
    // Send multiple requests to demonstrate concurrent monitoring
    await Future.wait([
      _apiService.getPosts(),
      _apiService.createPost(),
      _apiService.updatePost(),
    ]);
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
    _dio.interceptors.add(const NetworkLoggerInterceptor());

    // Add a basic logging interceptor for console output (optional)
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        logPrint: (obj) {
          // Only log to console in this example for demonstration
          debugPrint(obj.toString());
        },
      ),
    );
  }

  Future<void> getPosts() async {
    final response = await _dio.get('/posts');
    debugPrint('GET Posts: ${response.statusCode}');
  }

  Future<void> createPost() async {
    final response = await _dio.post(
      '/posts',
      data: {
        'title': 'Test Post from Cote Network Logger',
        'body': 'This is a test post created via Cote Network Logger example app. '
            'You should see this request details in the dashboard!',
        'userId': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {
          'source': 'cote_network_logger_example',
          'version': '1.0.0',
          'platform': 'flutter',
        },
      },
    );
    debugPrint('POST Create: ${response.statusCode}');
  }

  Future<void> updatePost() async {
    final response = await _dio.put(
      '/posts/1',
      data: {
        'id': 1,
        'title': 'Updated Test Post via Cote Network Logger',
        'body': 'This post has been updated via Cote Network Logger example app. '
            'Check the dashboard to see request/response details!',
        'userId': 1,
        'lastUpdated': DateTime.now().toIso8601String(),
        'updatedBy': 'cote_network_logger_demo',
      },
    );
    debugPrint('PUT Update: ${response.statusCode}');
  }

  Future<void> deletePost() async {
    final response = await _dio.delete('/posts/1');
    debugPrint('DELETE Post: ${response.statusCode}');
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
