import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sms_over_wifi/sms_over_wifi.dart';
import 'package:test/test.dart';

class _RecordingTransport implements EmailTransport {
  final List<Map<String, String>> sent = [];
  bool throwOnSend = false;
  Object? throwError;
  int sendCount = 0;
  bool configured = true;

  @override
  Future<bool> get isConfigured async => configured;

  @override
  Future<void> send({
    required String from,
    required String to,
    required String body,
    String subject = '',
  }) async {
    sendCount++;
    if (throwOnSend) {
      throw throwError ?? Exception('smtp down');
    }
    sent.add({'from': from, 'to': to, 'body': body, 'subject': subject});
  }
}

void main() {
  tearDown(SmsOverWifi.reset);

  group('PhoneNumber', () {
    test('strips non-digits', () {
      expect(PhoneNumber.digitsOnly('+1 (555) 123-4567'), '15551234567');
    });

    test('normalizes US numbers for gateways', () {
      expect(
        PhoneNumber.forGateway('+1-555-123-4567', countryCode: 'US'),
        '5551234567',
      );
      expect(
        PhoneNumber.forGateway('5551234567', countryCode: 'US'),
        '5551234567',
      );
    });

    test('toE164 adds plus and country code', () {
      expect(
        PhoneNumber.toE164('5551234567', countryCode: 'US'),
        '+15551234567',
      );
    });

    test('plausibility bounds', () {
      expect(PhoneNumber.isPlausible('5551234567', countryCode: 'US'), isTrue);
      expect(PhoneNumber.isPlausible('123'), isFalse);
    });
  });

  group('CarrierGateways', () {
    test('resolves known carriers and aliases', () {
      expect(CarrierGateways.domainFor('AT&T'), 'txt.att.net');
      expect(CarrierGateways.domainFor('att'), 'txt.att.net');
      expect(CarrierGateways.domainFor('vzw'), 'vtext.com');
      expect(CarrierGateways.domainFor('T-Mobile'), 'tmomail.net');
      expect(
        CarrierGateways.addressFor(
          phoneDigits: '5551234567',
          carrier: 'verizon',
        ),
        '5551234567@vtext.com',
      );
      expect(CarrierGateways.domainFor('unknown-carrier'), isNull);
    });
  });

  group('SmsSegments', () {
    test('counts gsm single and multi segment', () {
      expect(SmsSegments.count('hi'), 1);
      expect(SmsSegments.count('a' * 160), 1);
      expect(SmsSegments.count('a' * 161), 2);
    });

    test('counts unicode shorter segments', () {
      expect(SmsSegments.count('你好'), 1);
      expect(SmsSegments.count('你' * 71), greaterThan(1));
    });
  });

  group('EmailSmsService', () {
    test('sends to carrier gateway over transport', () async {
      final transport = _RecordingTransport();
      final service = EmailSmsService(
        fromEmail: 'me@gmail.com',
        transport: transport,
        defaultCarrier: 'att',
      );

      final result = await service.sendSms(
        phoneNumber: '+1 555 123 4567',
        message: 'Hello Wi-Fi SMS',
      );

      expect(result.success, isTrue);
      expect(result.gatewayAddress, '5551234567@txt.att.net');
      expect(result.segmentCount, 1);
      expect(transport.sent, hasLength(1));
      expect(transport.sent.single['to'], '5551234567@txt.att.net');
      expect(transport.sent.single['body'], 'Hello Wi-Fi SMS');
    });

    test('requires carrier with error code', () async {
      final service = EmailSmsService(
        fromEmail: 'me@gmail.com',
        transport: _RecordingTransport(),
      );

      final result = await service.sendSms(
        phoneNumber: '5551234567',
        message: 'hi',
      );

      expect(result.success, isFalse);
      expect(result.errorCode, SmsErrorCode.carrierRequired);
      expect(result.error, contains('Carrier is required'));
    });

    test('rejects empty message', () async {
      final service = EmailSmsService(
        fromEmail: 'me@gmail.com',
        transport: _RecordingTransport(),
        defaultCarrier: 'att',
      );

      final result = await service.sendSms(
        phoneNumber: '5551234567',
        message: '   ',
      );

      expect(result.success, isFalse);
      expect(result.errorCode, SmsErrorCode.emptyMessage);
    });

    test('reports SMTP failures with code', () async {
      final transport = _RecordingTransport()..throwOnSend = true;
      final service = EmailSmsService(
        fromEmail: 'me@gmail.com',
        transport: transport,
        defaultCarrier: 'verizon',
      );

      final result = await service.sendSms(
        phoneNumber: '5551234567',
        message: 'hi',
      );

      expect(result.success, isFalse);
      expect(result.errorCode, SmsErrorCode.smtp);
      expect(result.error, contains('SMTP send failed'));
    });

    test('maps auth failures', () async {
      final transport = _RecordingTransport()
        ..throwOnSend = true
        ..throwError = Exception('535 Username and Password not accepted');
      final service = EmailSmsService(
        fromEmail: 'me@gmail.com',
        transport: transport,
        defaultCarrier: 'att',
      );

      final result = await service.sendSms(
        phoneNumber: '5551234567',
        message: 'hi',
      );

      expect(result.errorCode, SmsErrorCode.auth);
    });

    test('bulk send skips trailing delay and maps results', () async {
      final transport = _RecordingTransport();
      final service = EmailSmsService(
        fromEmail: 'me@gmail.com',
        transport: transport,
        defaultCarrier: 'att',
      );

      final started = DateTime.now();
      final results = await service.sendBulkSms(
        phoneNumbers: ['5551111111', '5552222222'],
        message: 'bulk',
        delayBetween: Duration.zero,
      );
      final elapsed = DateTime.now().difference(started);

      expect(results.length, 2);
      expect(results.values.every((r) => r.success), isTrue);
      expect(transport.sent, hasLength(2));
      expect(elapsed.inMilliseconds, lessThan(500));
    });

    test('isServiceAvailable respects transport', () async {
      final transport = _RecordingTransport()..configured = false;
      final service = EmailSmsService(
        fromEmail: 'me@gmail.com',
        transport: transport,
        defaultCarrier: 'att',
      );
      expect(await service.isServiceAvailable(), isFalse);
    });
  });

  group('SmtpEmailTransport OAuth refresh', () {
    test('factory accepts refresh callback', () {
      final transport = SmtpEmailTransport.gmailOAuth(
        email: 'user@gmail.com',
        accessToken: 'ya29.old',
        onRefreshToken: () async => 'ya29.new',
      );
      expect(transport, isA<EmailTransport>());
    });
  });

  group('WebSmsService', () {
    test('parses successful Textbelt response', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'textbelt.com');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['phone'], '15551234567');
        expect(body['message'], 'ping');
        return http.Response(jsonEncode({'success': true}), 200);
      });

      final service = WebSmsService(client: client);
      final result = await service.sendSms(
        phoneNumber: '555-123-4567',
        message: 'ping',
        countryCode: 'US',
      );

      expect(result.success, isTrue);
      expect(result.segmentCount, 1);
    });

    test('surfaces API errors with quota code', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'success': false, 'error': 'Out of quota'}),
          200,
        );
      });

      final service = WebSmsService(client: client);
      final result = await service.sendSms(
        phoneNumber: '5551234567',
        message: 'ping',
        countryCode: 'US',
      );

      expect(result.success, isFalse);
      expect(result.error, 'Out of quota');
      expect(result.errorCode, SmsErrorCode.quota);
    });

    test('probes textbelt quota for availability', () async {
      final client = MockClient((request) async {
        expect(request.url.path, contains('/quota/'));
        return http.Response(
          jsonEncode({'success': true, 'quotaRemaining': 3}),
          200,
        );
      });

      final service = WebSmsService(client: client, apiKey: 'textbelt');
      expect(await service.isServiceAvailable(), isTrue);
    });

    test('supports custom JsonSmsProvider', () async {
      final client = MockClient((request) async {
        expect(request.url.host, 'sms.example.com');
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final service = WebSmsService(
        client: client,
        apiKey: 'secret',
        provider: JsonSmsProvider(
          name: 'example',
          endpoint: Uri.parse('https://sms.example.com/send'),
        ),
      );

      final result = await service.sendSms(
        phoneNumber: '+15551234567',
        message: 'custom',
      );
      expect(result.success, isTrue);
      expect(result.gatewayAddress, 'example');
    });
  });

  group('TwilioSmsService', () {
    test('sends form body and parses sid', () async {
      final client = MockClient((request) async {
        expect(request.url.path, contains('/Messages.json'));
        expect(request.headers['authorization'], startsWith('Basic '));
        return http.Response(jsonEncode({'sid': 'SM123'}), 201);
      });

      final service = TwilioSmsService(
        accountSid: 'ACxxx',
        authToken: 'token',
        fromNumber: '+15017122661',
        client: client,
      );

      final result = await service.sendSms(
        phoneNumber: '+263782926585',
        message: 'hi zw',
      );

      expect(result.success, isTrue);
      expect(result.gatewayAddress, 'twilio:SM123');
      expect(result.errorCode, isNull);
    });

    test('maps 401 to auth code', () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode({'message': 'Authenticate'}),
          401,
        ),
      );

      final service = TwilioSmsService(
        accountSid: 'ACxxx',
        authToken: 'bad',
        fromNumber: '+15017122661',
        client: client,
      );

      final result = await service.sendSms(
        phoneNumber: '+15551234567',
        message: 'hi',
      );
      expect(result.errorCode, SmsErrorCode.auth);
    });
  });

  group('SmsOverWifi facade', () {
    test('initialize requires credentials', () async {
      expect(SmsOverWifi.initialize(), throwsArgumentError);
    });

    test('sendSms fails before initialize', () async {
      final result = await SmsOverWifi.sendSms(
        phoneNumber: '5551234567',
        message: 'hi',
        carrier: 'att',
      );
      expect(result.success, isFalse);
      expect(result.errorCode, SmsErrorCode.notInitialized);
    });

    test('initialize twilio path', () async {
      final service = await SmsOverWifi.initialize(
        twilioAccountSid: 'ACxxx',
        twilioAuthToken: 'token',
        twilioFromNumber: '+15017122661',
      );
      expect(service, isA<TwilioSmsService>());
      expect(SmsOverWifi.version, '1.3.0');
    });

    test('initialize email gmail OAuth path with refresh', () async {
      final service = await SmsOverWifi.initialize(
        email: 'user@gmail.com',
        accessToken: 'ya29.fake-token',
        defaultCarrier: 'att',
        onAccessTokenRefresh: () async => 'ya29.refreshed',
      );
      expect(service, isA<EmailSmsService>());
      expect(await service.isServiceAvailable(), isTrue);
      expect(SmsOverWifi.gmailMailScope, 'https://mail.google.com/');
    });

    test('initialize still accepts legacy password arg', () async {
      final service = await SmsOverWifi.initialize(
        email: 'user@gmail.com',
        password: 'app-pass',
        defaultCarrier: 'att',
      );
      expect(service, isA<EmailSmsService>());
    });
  });

  group('withRetries', () {
    test('retries then succeeds', () async {
      var attempts = 0;
      final value = await withRetries(
        () async {
          attempts++;
          if (attempts < 2) throw Exception('transient');
          return 42;
        },
        options: const SendOptions(
          timeout: Duration(seconds: 2),
          maxAttempts: 3,
          retryDelay: Duration.zero,
        ),
      );
      expect(value, 42);
      expect(attempts, 2);
    });
  });
}
