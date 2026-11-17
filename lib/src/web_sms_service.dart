import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'interfaces.dart';
import 'phone.dart';
import 'retry.dart';
import 'segments.dart';
import 'web_sms_provider.dart';

/// Sends SMS through an HTTP SMS API over Wi-Fi.
///
/// Defaults to [TextbeltProvider]. Pass another [WebSmsProvider] for custom APIs.
class WebSmsService extends SmsServiceBase {
  final http.Client _client;
  final WebSmsProvider provider;
  final String apiKey;
  final SendOptions sendOptions;
  final bool _ownsClient;

  WebSmsService({
    http.Client? client,
    WebSmsProvider? provider,
    Uri? endpoint,
    this.apiKey = 'textbelt',
    this.sendOptions = SendOptions.defaults,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        provider = provider ??
            TextbeltProvider(
              endpoint: endpoint ?? Uri.parse('https://textbelt.com/text'),
            );

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

    // E.164 for generic APIs; Textbelt expects digits with country code, no '+'.
    final e164 = PhoneNumber.toE164(phoneNumber, countryCode: countryCode);
    final phone =
        provider is TextbeltProvider ? PhoneNumber.digitsOnly(e164) : e164;

    try {
      final response = await withRetries(
        () => _client.post(
          provider.endpoint,
          headers: provider.headers(apiKey),
          body: provider.body(
            phone: phone,
            message: trimmed,
            apiKey: apiKey,
          ),
        ),
        options: sendOptions,
        retryIf: isTimeoutError,
      );
      return provider.interpret(response, segmentCount: segments);
    } catch (e) {
      if (isTimeoutError(e) || e is TimeoutException) {
        return SmsResult.fail(
          'Web SMS request timed out: $e',
          errorCode: SmsErrorCode.timeout,
          segmentCount: segments,
        );
      }
      return SmsResult.fail(
        'Web SMS request failed: $e',
        errorCode: SmsErrorCode.http,
        segmentCount: segments,
      );
    }
  }

  @override
  Future<bool> isServiceAvailable() async {
    try {
      final Uri probe;
      if (provider is TextbeltProvider) {
        probe = TextbeltProvider.quotaUri(apiKey);
      } else if (provider.healthEndpoint != null) {
        probe = provider.healthEndpoint!;
      } else {
        probe = provider.endpoint;
      }

      final response = await _client
          .get(probe)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode >= 500) return false;

      if (provider is TextbeltProvider) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('success')) {
            return data['success'] == true || data['quotaRemaining'] != null;
          }
        } catch (_) {}
      }
      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}
