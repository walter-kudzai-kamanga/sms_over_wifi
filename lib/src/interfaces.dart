/// Contract every SMS delivery backend must implement.
abstract class SmsService {
  Future<SmsResult> sendSms({
    required String phoneNumber,
    required String message,
    String? countryCode,
    String? carrier,
  });

  Future<Map<String, SmsResult>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    String? countryCode,
    String? carrier,
    Duration delayBetween = const Duration(milliseconds: 100),
  });

  /// Returns whether the backend looks ready to send.
  ///
  /// Implementations should probe the remote service when possible
  /// (quota/account endpoints), not merely check that strings are non-empty.
  Future<bool> isServiceAvailable();
}

/// Shared [sendBulkSms] so backends only implement [sendSms].
abstract class SmsServiceBase implements SmsService {
  @override
  Future<Map<String, SmsResult>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    String? countryCode,
    String? carrier,
    Duration delayBetween = const Duration(milliseconds: 100),
  }) async {
    final results = <String, SmsResult>{};
    for (var i = 0; i < phoneNumbers.length; i++) {
      final number = phoneNumbers[i];
      results[number] = await sendSms(
        phoneNumber: number,
        message: message,
        countryCode: countryCode,
        carrier: carrier,
      );
      if (i < phoneNumbers.length - 1 && delayBetween > Duration.zero) {
        await Future<void>.delayed(delayBetween);
      }
    }
    return results;
  }
}

/// Machine-readable failure reason for [SmsResult].
enum SmsErrorCode {
  emptyMessage,
  invalidNumber,
  carrierRequired,
  unknownCarrier,
  auth,
  quota,
  smtp,
  http,
  timeout,
  notInitialized,
  unavailable,
  unknown,
}

/// Outcome of a single send attempt.
class SmsResult {
  final bool success;
  final String? error;
  final SmsErrorCode? errorCode;
  final String? gatewayAddress;

  /// GSM/Unicode SMS segment estimate for the outbound body.
  final int? segmentCount;

  /// True when [segmentCount] is greater than 1.
  bool get multiSegment => (segmentCount ?? 1) > 1;

  const SmsResult({
    required this.success,
    this.error,
    this.errorCode,
    this.gatewayAddress,
    this.segmentCount,
  });

  factory SmsResult.ok({
    String? gatewayAddress,
    int? segmentCount,
  }) =>
      SmsResult(
        success: true,
        gatewayAddress: gatewayAddress,
        segmentCount: segmentCount,
      );

  factory SmsResult.fail(
    String error, {
    SmsErrorCode errorCode = SmsErrorCode.unknown,
    String? gatewayAddress,
    int? segmentCount,
  }) =>
      SmsResult(
        success: false,
        error: error,
        errorCode: errorCode,
        gatewayAddress: gatewayAddress,
        segmentCount: segmentCount,
      );

  @override
  String toString() {
    if (success) {
      return 'SmsResult.ok($gatewayAddress, segments=$segmentCount)';
    }
    return 'SmsResult.fail($errorCode: $error)';
  }
}
