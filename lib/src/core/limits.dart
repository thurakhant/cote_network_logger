/// UTF-8 capture and retention budgets. Validation occurs at configuration time.
class LoggerLimits {
  const LoggerLimits({
    this.maxCalls = 200,
    this.maxStoreBytes = 8388608,
    this.maxBodyBytes = 65536,
    this.maxHeadersBytes = 16384,
    this.maxUrlBytes = 4096,
    this.maxErrorBytes = 1024,
    this.maxDepth = 16,
    this.maxVisitedNodes = 10000,
    this.maxScalarBytes = 65536,
  });
  final int maxCalls,
      maxStoreBytes,
      maxBodyBytes,
      maxHeadersBytes,
      maxUrlBytes,
      maxErrorBytes,
      maxDepth,
      maxVisitedNodes,
      maxScalarBytes;
  void validate() {
    for (final entry in toJson().entries) {
      if (entry.value <= 0) {
        throw ArgumentError.value(entry.value, entry.key, 'Must be positive');
      }
    }
  }

  Map<String, int> toJson() => {
        'maxCalls': maxCalls,
        'maxStoreBytes': maxStoreBytes,
        'maxBodyBytes': maxBodyBytes,
        'maxHeadersBytes': maxHeadersBytes,
        'maxUrlBytes': maxUrlBytes,
        'maxErrorBytes': maxErrorBytes,
        'maxDepth': maxDepth,
        'maxVisitedNodes': maxVisitedNodes,
        'maxScalarBytes': maxScalarBytes,
      };
}
