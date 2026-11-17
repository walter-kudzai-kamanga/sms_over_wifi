import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'interfaces.dart';
import 'phone.dart';
import 'retry.dart';
import 'segments.dart';

/// Sends SMS worldwide over Wi-Fi via the [Twilio](https://www.twilio.com) REST API.
///
/// Best path for countries without email-to-SMS gateways (e.g. Zimbabwe).
class TwilioSmsService extends SmsServiceBase {
  final String accountSid;
  final String authToken;
  final String fromNumber;
  final http.Client _client;
  final SendOptions sendOptions;
  final bool _ownsClient;

  TwilioSmsService({
    required this.accountSid,
    required this.authToken,
    required this.fromNumber,
    http.Client? client,
    this.sendOptions = SendOptions.defaults,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  Uri get _messagesUri => Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json',
      );

  Uri get _accountUri => Uri.parse(
        'https://api.twilio.com/2010-04-01/Accounts/$accountSid.json',
      );

  String get _basicAuth =>
      'Basic ${base64Encode(utf8.encode('$accountSid:$authToken'))}';

  /// E.164 (`+263782926585`).
  static String toE164(String phoneNumber, {String? countryCode}) =>
      PhoneNumber.toE164(phoneNumber, countryCode: countryCode);

  @override
  Future<SmsResult> sendSms({
    required String phoneNumber,
    required String message,
    String? countryCode,
    String? carrier,
  }) async {
    final trimmed = message.trim();
    final segments = SmsSegments.count(trimmed);
    if (trimmed.isEmpty) {
      return SmsResult.fail(
        'Message must not be empty',
        errorCode: SmsErrorCode.emptyMessage,
        segmentCount: 0,
      );
    }

    if (!PhoneNumber.isPlausible(phoneNumber, countryCode: countryCode)) {
      return SmsResult.fail(
        'Invalid phone number: $phoneNumber',
        errorCode: SmsErrorCode.invalidNumber,
        segmentCount: segments,
      );
    }

    final to = toE164(phoneNumber, countryCode: countryCode);
    final from = toE164(fromNumber);

    try {
      final response = await withRetries(
        () => _client.post(
          _messagesUri,
          headers: {
            'Authorization': _basicAuth,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {
            'To': to,
            'From': from,
            'Body': trimmed,
          },
        ),
        options: sendOptions,
        retryIf: isTimeoutError,
      );

      final body = response.body;
      Map<String, dynamic>? data;
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map<String, dynamic>) data = decoded;
      } catch (_) {}

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final sid = data?['sid']?.toString();
        return SmsResult.ok(
          gatewayAddress: sid != null ? 'twilio:$sid' : 'twilio',
          segmentCount: segments,
        );
      }

      final twilioError = data?['message']?.toString() ??
          data?['error_message']?.toString() ??
          body;
      final code = response.statusCode == 401 || response.statusCode == 403
          ? SmsErrorCode.auth
          : (twilioError.toLowerCase().contains('quota') ||
                  twilioError.toLowerCase().contains('limit')
              ? SmsErrorCode.quota
              : SmsErrorCode.http);
      return SmsResult.fail(
        'Twilio HTTP ${response.statusCode}: $twilioError',
        errorCode: code,
        segmentCount: segments,
      );
    } catch (e) {
      if (isTimeoutError(e) || e is TimeoutException) {
        return SmsResult.fail(
          'Twilio request timed out: $e',
          errorCode: SmsErrorCode.timeout,
          segmentCount: segments,
        );
      }
      return SmsResult.fail(
        'Twilio request failed: $e',
        errorCode: SmsErrorCode.http,
        segmentCount: segments,
      );
    }
  }

  @override
  Future<bool> isServiceAvailable() async {
    if (accountSid.isEmpty || authToken.isEmpty || fromNumber.isEmpty) {
      return false;
    }
    try {
      final response = await _client
          .get(
            _accountUri,
            headers: {'Authorization': _basicAuth},
          )
          .timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
