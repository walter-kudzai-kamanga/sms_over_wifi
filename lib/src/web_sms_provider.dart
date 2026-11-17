import 'dart:convert';

import 'package:http/http.dart' as http;

import 'interfaces.dart';

/// Pluggable HTTP SMS API shape used by [WebSmsService].
abstract class WebSmsProvider {
  String get name;

  Uri get endpoint;

  /// Optional health/quota URL used by [isServiceAvailable].
  Uri? get healthEndpoint => null;

  Map<String, String> headers(String apiKey);

  Object body({
    required String phone,
    required String message,
    required String apiKey,
  });

  SmsResult interpret(http.Response response, {int? segmentCount});
}

/// Default Textbelt JSON provider (`https://textbelt.com/text`).
class TextbeltProvider implements WebSmsProvider {
  final Uri endpointOverride;

  TextbeltProvider({Uri? endpoint})
      : endpointOverride =
            endpoint ?? Uri.parse('https://textbelt.com/text');

  @override
  String get name => 'textbelt';

  @override
  Uri get endpoint => endpointOverride;

  @override
  Uri? get healthEndpoint {
    // Quota endpoint requires the key; WebSmsService fills it in.
    return null;
  }

  /// Textbelt quota probe for a concrete API key.
  static Uri quotaUri(String apiKey) =>
      Uri.parse('https://textbelt.com/quota/$apiKey');

  @override
  Map<String, String> headers(String apiKey) => {
        'Content-Type': 'application/json',
      };

  @override
  Object body({
    required String phone,
    required String message,
    required String apiKey,
  }) {
    return jsonEncode({
      'phone': phone,
      'message': message,
      'key': apiKey,
    });
  }

  @override
  SmsResult interpret(http.Response response, {int? segmentCount}) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return SmsResult.fail(
        'HTTP ${response.statusCode}: ${response.body}',
        errorCode: SmsErrorCode.http,
        segmentCount: segmentCount,
      );
    }

    final data = jsonDecode(response.body);
    if (data is Map && data['success'] == true) {
      return SmsResult.ok(
        gatewayAddress: name,
        segmentCount: segmentCount,
      );
    }

    final error = data is Map ? data['error']?.toString() : null;
    final lower = (error ?? '').toLowerCase();
    final code = lower.contains('quota') || lower.contains('limit')
        ? SmsErrorCode.quota
        : SmsErrorCode.http;
    return SmsResult.fail(
      error ?? 'API rejected the message',
      errorCode: code,
      segmentCount: segmentCount,
    );
  }
}

/// Generic JSON SMS provider for APIs that accept
/// `{phone, message, key}` and return `{success: bool, error?: string}`.
class JsonSmsProvider implements WebSmsProvider {
  @override
  final String name;
  @override
  final Uri endpoint;
  @override
  final Uri? healthEndpoint;
  final String phoneField;
  final String messageField;
  final String keyField;

  JsonSmsProvider({
    required this.name,
    required this.endpoint,
    this.healthEndpoint,
    this.phoneField = 'phone',
    this.messageField = 'message',
    this.keyField = 'key',
  });

  @override
  Map<String, String> headers(String apiKey) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      };

  @override
  Object body({
    required String phone,
    required String message,
    required String apiKey,
  }) {
    return jsonEncode({
      phoneField: phone,
      messageField: message,
      keyField: apiKey,
    });
  }

  @override
  SmsResult interpret(http.Response response, {int? segmentCount}) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return SmsResult.fail(
        'HTTP ${response.statusCode}: ${response.body}',
        errorCode: SmsErrorCode.http,
        gatewayAddress: name,
        segmentCount: segmentCount,
      );
    }
    try {
      final data = jsonDecode(response.body);
      if (data is Map && (data['success'] == true || data['ok'] == true)) {
        return SmsResult.ok(
          gatewayAddress: name,
          segmentCount: segmentCount,
        );
      }
      final error = data is Map ? data['error']?.toString() : null;
      return SmsResult.fail(
        error ?? 'API rejected the message',
        errorCode: SmsErrorCode.http,
        gatewayAddress: name,
        segmentCount: segmentCount,
      );
    } catch (e) {
      return SmsResult.fail(
        'Invalid API response: $e',
        errorCode: SmsErrorCode.http,
        gatewayAddress: name,
        segmentCount: segmentCount,
      );
    }
  }
}
