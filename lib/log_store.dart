/// A simple in-memory store for network logs during development.
///
/// **Real-time Tracking Only:**
/// - ✅ Keeps logs in memory for current session
/// - ✅ Automatically cleans old logs (keeps last 100)
/// - ✅ No persistent storage needed
/// - ✅ Perfect for development monitoring
///
/// **Features:**
/// - 🚀 Fast in-memory operations
/// - 🔄 Auto-cleanup of old logs
/// - 💾 Memory efficient
/// - 📊 Real-time dashboard updates
class NetworkLogStore {
  NetworkLogStore._internal();
  static final NetworkLogStore _instance = NetworkLogStore._internal();

  /// Returns the singleton instance of NetworkLogStore.
  static NetworkLogStore get instance => _instance;

  /// In-memory storage for network logs
  final List<Map<String, dynamic>> _logs = [];

  /// Maximum number of logs to keep in memory
  static const int _maxLogs = 100;

  /// Adds a new network log entry.
  ///
  /// Automatically removes old logs if we exceed the maximum count.
  /// This keeps memory usage reasonable during development.
  void addLog(Map<String, dynamic> log) {
    _logs.add({
      ...log,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Auto-cleanup: keep only the most recent logs
    if (_logs.length > _maxLogs) {
      final logsToRemove = _logs.length - _maxLogs;
      _logs.removeRange(0, logsToRemove);
    }
  }

  /// Returns all current logs in memory.
  ///
  /// Returns logs in reverse chronological order (newest first).
  List<Map<String, dynamic>> getLogs() {
    return List.from(_logs.reversed);
  }

  /// Clears all logs from memory.
  ///
  /// Useful for starting fresh during development.
  void clearLogs() {
    _logs.clear();
  }

  /// Returns the current number of logs in memory.
  int get logCount => _logs.length;

  /// Returns whether the store has reached its maximum capacity.
  bool get isFull => _logs.length >= _maxLogs;
}
