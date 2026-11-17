// ignore_for_file: avoid_print

import 'dart:io';

import 'package:sms_over_wifi/sms_over_wifi.dart';

/// Minimal CLI example. Prefer env vars — never hard-code secrets.
///
/// ```sh
/// dart run example/sms_over_wifi_example.dart
/// ```
Future<void> main(List<String> args) async {
  final sid = Platform.environment['TWILIO_ACCOUNT_SID'];
  final token = Platform.environment['TWILIO_AUTH_TOKEN'];
  final from = Platform.environment['TWILIO_FROM_NUMBER'];
  final to = Platform.environment['SMS_TO'] ?? '+15551234567';

  if (sid == null || token == null || from == null) {
    stderr.writeln(
      'Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER '
      '(and optionally SMS_TO).',
    );
    exitCode = 64;
    return;
  }

  final sms = TwilioSmsService(
    accountSid: sid,
    authToken: token,
    fromNumber: from,
    sendOptions: const SendOptions(
      timeout: Duration(seconds: 20),
      maxAttempts: 2,
    ),
  );

  final available = await sms.isServiceAvailable();
  print('Twilio available: $available');

  final result = await sms.sendSms(
    phoneNumber: to,
    message: 'Hello over Wi-Fi via sms_over_wifi ${SmsOverWifi.version}',
  );

  if (result.success) {
    print('Sent via ${result.gatewayAddress} '
        '(${result.segmentCount} segment(s))');
  } else {
    stderr.writeln('${result.errorCode}: ${result.error}');
    exitCode = 1;
  }

  sms.close();
}
