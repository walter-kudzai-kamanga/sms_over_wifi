import 'dart:async';

/// Timeouts and limited retries for network-backed SMS sends.
class SendOptions {
  /// Per-attempt timeout.
  final Duration timeout;

  /// Total tries including the first attempt.
  final int maxAttempts;

  /// Delay between failed attempts.
  final Duration retryDelay;

  const SendOptions({
    this.timeout = const Duration(seconds: 30),
    this.maxAttempts = 2,
    this.retryDelay = const Duration(milliseconds: 400),
  });

  static const SendOptions defaults = SendOptions();
}

/// Runs [action] with [SendOptions.timeout] and limited retries.
Future<T> withRetries<T>(
  Future<T> Function() action, {
  SendOptions options = SendOptions.defaults,
  bool Function(Object error)? retryIf,
}) async {
  if (options.maxAttempts < 1) {
    throw ArgumentError.value(
      options.maxAttempts,
      'maxAttempts',
      'must be >= 1',
    );
  }

  Object? lastError;
  StackTrace? lastTrace;
  for (var attempt = 1; attempt <= options.maxAttempts; attempt++) {
    try {
      return await action().timeout(options.timeout);
    } catch (e, st) {
      lastError = e;
      lastTrace = st;
      final canRetry =
          attempt < options.maxAttempts && (retryIf == null || retryIf(e));
      if (!canRetry) {
        Error.throwWithStackTrace(e, st);
      }
      await Future<void>.delayed(options.retryDelay);
    }
  }
  Error.throwWithStackTrace(lastError!, lastTrace ?? StackTrace.current);
}

bool isTimeoutError(Object error) {
  final text = error.toString().toLowerCase();
  return error is TimeoutException ||
      text.contains('timeout') ||
      text.contains('timed out');
}
