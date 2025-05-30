import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:async';

void main() {
  runApp(const CoteNetworkDashboard());
}

class CoteNetworkDashboard extends StatelessWidget {
  const CoteNetworkDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'coTe Network Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF667EEA),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<NetworkTransaction> transactions = [];
  List<NetworkTransaction> filteredTransactions = [];
  Set<String> expandedRows = <String>{};

  String searchTerm = '';
  String methodFilter = '';
  String statusFilter = '';

  bool isLoading = true;
  String? errorMessage;
  DateTime? lastUpdated;

  Timer? refreshTimer;
  bool userInteracting = false;
  Timer? interactionTimer;

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    interactionTimer?.cancel();
    super.dispose();
  }

  void _setUserInteracting() {
    setState(() {
      userInteracting = true;
    });

    interactionTimer?.cancel();
    interactionTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        setState(() {
          userInteracting = false;
        });
        _loadLogs();
      }
    });
  }

  void _startAutoRefresh() {
    refreshTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!userInteracting && mounted) {
        _loadLogs();
      }
    });
  }

  Future<void> _loadLogs() async {
    if (!mounted) return;

    try {
      final response = await _fetchLogs();
      final data = jsonDecode(response);

      if (mounted) {
        setState(() {
          final logs = List<Map<String, dynamic>>.from(data['logs'] ?? []);
          _processLogs(logs);
          isLoading = false;
          errorMessage = null;
          lastUpdated = DateTime.now();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load logs: $e';
        });
      }
    }
  }

  Future<String> _fetchLogs() async {
    final request = html.HttpRequest();
    final completer = Completer<String>();

    request.open('GET', '/logs?t=${DateTime.now().millisecondsSinceEpoch}');
    request.onLoad.listen((_) {
      if (request.status == 200) {
        completer.complete(request.responseText!);
      } else {
        completer.completeError('HTTP ${request.status}');
      }
    });
    request.onError.listen((_) {
      completer.completeError('Network error');
    });
    request.send();

    return completer.future;
  }

  void _processLogs(List<Map<String, dynamic>> logs) {
    final Map<String, NetworkTransaction> requestTransactions = {};
    final List<Map<String, dynamic>> responseOrErrorLogs = [];

    // Process requests first
    for (final log in logs) {
      if (log['type'] == 'request') {
        final transactionId = 'req_${log['id']}';
        requestTransactions[transactionId] = NetworkTransaction(
          id: transactionId,
          url: log['url'] ?? '',
          method: log['method'] ?? 'UNKNOWN',
          request: log,
          timestamp: DateTime.parse(log['timestamp'] ?? DateTime.now().toIso8601String()),
        );
      } else {
        responseOrErrorLogs.add(log);
      }
    }

    // Match responses and errors
    for (final log in responseOrErrorLogs) {
      NetworkTransaction? bestMatch;
      Duration smallestDiff = const Duration(days: 1);

      for (final transaction in requestTransactions.values) {
        if (transaction.method == log['method'] && transaction.url == log['url']) {
          final timeDiff = DateTime.parse(log['timestamp'] ?? DateTime.now().toIso8601String()).difference(transaction.timestamp).abs();

          if (timeDiff < smallestDiff && timeDiff < const Duration(seconds: 30)) {
            final canMatch = (log['type'] == 'response' && transaction.response == null) || (log['type'] == 'error' && transaction.error == null);

            if (canMatch) {
              bestMatch = transaction;
              smallestDiff = timeDiff;
            }
          }
        }
      }

      if (bestMatch != null) {
        if (log['type'] == 'response') {
          bestMatch.response = log;
        } else if (log['type'] == 'error') {
          bestMatch.error = log;
        }
      }
    }

    transactions = requestTransactions.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    _applyFilters();
  }

  void _applyFilters() {
    filteredTransactions = transactions.where((transaction) {
      final matchesSearch = searchTerm.isEmpty || transaction.url.toLowerCase().contains(searchTerm.toLowerCase()) || transaction.method.toLowerCase().contains(searchTerm.toLowerCase());

      final matchesMethod = methodFilter.isEmpty || transaction.method == methodFilter;

      final statusCode = _getStatusCode(transaction);
      final matchesStatus = statusFilter.isEmpty ||
          (statusFilter == '2xx' && statusCode >= 200 && statusCode < 300) ||
          (statusFilter == '4xx' && statusCode >= 400 && statusCode < 500) ||
          (statusFilter == '5xx' && statusCode >= 500);

      return matchesSearch && matchesMethod && matchesStatus;
    }).toList();
  }

  int _getStatusCode(NetworkTransaction transaction) {
    if (transaction.error != null) return 0;
    if (transaction.response != null && transaction.response!['statusCode'] != null) {
      return transaction.response!['statusCode'] as int;
    }
    return -1;
  }

  Future<void> _clearLogs() async {
    try {
      final request = html.HttpRequest();
      request.open('POST', '/logs/clear');
      request.send();

      await request.onLoad.first;

      if (request.status == 200 && mounted) {
        setState(() {
          transactions.clear();
          filteredTransactions.clear();
          expandedRows.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Logs cleared successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to clear logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildControls(),
                const SizedBox(height: 24),
                Expanded(child: _buildTransactionsList()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '🚀 coTe Network Dashboard',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              foreground: Paint()
                ..shader = const LinearGradient(
                  colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pure Flutter Web • Real-time HTTP monitoring',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStats(),
          const SizedBox(height: 16),
          _buildActionButtons(),
          const SizedBox(height: 16),
          _buildFilters(),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final requests = transactions.where((t) => t.request != null).length;
    final errors = transactions.where((t) => t.error != null || (_getStatusCode(t) >= 400 && _getStatusCode(t) < 600)).length;

    return Wrap(
      spacing: 20,
      runSpacing: 12,
      children: [
        _buildStatItem('Total', transactions.length.toString(), const Color(0xFF667EEA)),
        _buildStatItem('Requests', requests.toString(), const Color(0xFF667EEA)),
        _buildStatItem('Errors', errors.toString(), errors > 0 ? Colors.red : const Color(0xFF667EEA)),
        _buildStatItem('Updated', lastUpdated?.toLocal().toString().split(' ')[1].split('.')[0] ?? 'Never', const Color(0xFF38A169)),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF7FAFC), Color(0xFFEDF2F7)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4A5568),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ElevatedButton.icon(
          onPressed: () {
            _setUserInteracting();
            _loadLogs();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667EEA),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Clear All Logs'),
              content: const Text('Are you sure you want to clear all logs? This action cannot be undone.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _clearLogs();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.delete),
          label: const Text('Clear All'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE53E3E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            decoration: InputDecoration(
              hintText: '🔍 Search URLs, methods, status codes...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF667EEA), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                searchTerm = value;
              });
              _setUserInteracting();
              _applyFilters();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: methodFilter.isEmpty ? null : methodFilter,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: const Text('All Methods'),
            items: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'].map((method) => DropdownMenuItem(value: method, child: Text(method))).toList(),
            onChanged: (value) {
              setState(() {
                methodFilter = value ?? '';
              });
              _applyFilters();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: statusFilter.isEmpty ? null : statusFilter,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: const Text('All Status'),
            items: ['2xx', '4xx', '5xx']
                .map((status) => DropdownMenuItem(
                    value: status,
                    child: Text('$status ${status == '2xx' ? 'Success' : status == '4xx' ? 'Client Error' : 'Server Error'}')))
                .toList(),
            onChanged: (value) {
              setState(() {
                statusFilter = value ?? '';
              });
              _applyFilters();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionsList() {
    if (isLoading) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF667EEA)),
              SizedBox(height: 16),
              Text('🔄 Loading network logs...', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('⚠️ $errorMessage', style: const TextStyle(fontSize: 18, color: Colors.red)),
            ],
          ),
        ),
      );
    }

    if (filteredTransactions.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.98),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('📡 No network activity', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              Text('Make HTTP requests in your Flutter app to see them here', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification || notification is ScrollUpdateNotification) {
            _setUserInteracting();
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredTransactions.length,
          itemBuilder: (context, index) {
            final transaction = filteredTransactions[index];
            return TransactionCard(
              transaction: transaction,
              isExpanded: expandedRows.contains(transaction.id),
              onToggleExpanded: () {
                setState(() {
                  if (expandedRows.contains(transaction.id)) {
                    expandedRows.remove(transaction.id);
                  } else {
                    expandedRows.add(transaction.id);
                  }
                });
                _setUserInteracting();
              },
            );
          },
        ),
      ),
    );
  }
}

class NetworkTransaction {
  final String id;
  final String url;
  final String method;
  final Map<String, dynamic>? request;
  Map<String, dynamic>? response;
  Map<String, dynamic>? error;
  final DateTime timestamp;

  NetworkTransaction({
    required this.id,
    required this.url,
    required this.method,
    this.request,
    this.response,
    this.error,
    required this.timestamp,
  });
}

class TransactionCard extends StatelessWidget {
  final NetworkTransaction transaction;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(
              isExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              color: const Color(0xFF667EEA),
            ),
            title: Row(
              children: [
                _buildMethodChip(),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    transaction.url,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                _buildStatusChip(),
                const Spacer(),
                Text(
                  _formatTime(transaction.timestamp),
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
            onTap: onToggleExpanded,
          ),
          if (isExpanded) _buildExpandedContent(),
        ],
      ),
    );
  }

  Widget _buildMethodChip() {
    final colors = {
      'GET': [const Color(0xFFC6F6D5), const Color(0xFF22543D)],
      'POST': [const Color(0xFFFED7AA), const Color(0xFF9C4221)],
      'PUT': [const Color(0xFFBEE3F8), const Color(0xFF2A4365)],
      'DELETE': [const Color(0xFFFED7D7), const Color(0xFF742A2A)],
      'PATCH': [const Color(0xFFE9D8FD), const Color(0xFF553C9A)],
    };

    final methodColors = colors[transaction.method] ?? [Colors.grey[300]!, Colors.grey[800]!];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: methodColors[0],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        transaction.method,
        style: TextStyle(
          color: methodColors[1],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    final statusCode = _getStatusCode();
    final (color, text) = _getStatusDisplay(statusCode);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
    );
  }

  int _getStatusCode() {
    if (transaction.error != null) return 0;
    if (transaction.response != null && transaction.response!['statusCode'] != null) {
      return transaction.response!['statusCode'] as int;
    }
    return -1;
  }

  (Color, String) _getStatusDisplay(int statusCode) {
    if (statusCode == 0) return (Colors.red, 'ERROR');
    if (statusCode == -1) return (Colors.orange, 'PENDING');
    if (statusCode >= 200 && statusCode < 300) return (Colors.green, statusCode.toString());
    if (statusCode >= 300 && statusCode < 400) return (Colors.blue, statusCode.toString());
    if (statusCode >= 400 && statusCode < 500) return (Colors.red, statusCode.toString());
    if (statusCode >= 500) return (Colors.purple, statusCode.toString());
    return (Colors.grey, statusCode.toString());
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }

  Widget _buildExpandedContent() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Colors.grey[50],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (transaction.request != null) _buildRequestSection(),
          if (transaction.response != null) _buildResponseSection(),
          if (transaction.error != null) _buildErrorSection(),
        ],
      ),
    );
  }

  Widget _buildRequestSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📤 Request Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (transaction.request!['headers'] != null) _buildJsonDisplay('Headers', transaction.request!['headers']),
        if (transaction.request!['requestBody'] != null) _buildJsonDisplay('Body', transaction.request!['requestBody']),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildResponseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📥 Response Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (transaction.response!['headers'] != null) _buildJsonDisplay('Headers', transaction.response!['headers']),
        if (transaction.response!['responseBody'] != null) _buildJsonDisplay('Body', transaction.response!['responseBody']),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildErrorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '❌ Error Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
        ),
        const SizedBox(height: 8),
        _buildJsonDisplay('Error Information', transaction.error!),
      ],
    );
  }

  Widget _buildJsonDisplay(String title, dynamic content) {
    final jsonString = _formatJson(content);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxHeight: 400),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A202C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF4A5568)),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              jsonString,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  String _formatJson(dynamic data) {
    try {
      if (data is String) {
        try {
          final parsed = jsonDecode(data);
          return const JsonEncoder.withIndent('  ').convert(parsed);
        } catch (e) {
          return data;
        }
      }
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      return data.toString();
    }
  }
}
