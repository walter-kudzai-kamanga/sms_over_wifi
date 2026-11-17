import 'dart:async';

import 'carriers.dart';
import 'email_transport.dart';
import 'interfaces.dart';
import 'phone.dart';
import 'retry.dart';
import 'segments.dart';

/// Sends SMS by emailing carrier gateways (`number@carrier-gateway`) over Wi-Fi.
///
/// Carrier email gateways are best-effort and often unavailable outside
/// US/CA/UK. Prefer Twilio for production / international delivery.
class EmailSmsService extends SmsServiceBase {
  final String fromEmail;
  final EmailTransport transport;
  final String? defaultCarrier;

  EmailSmsService({
    required this.fromEmail,
    required this.transport,
    this.defaultCarrier,
  });

  /// Gmail via **Sign in with Google** OAuth access token (recommended).
  ///
  /// Required OAuth scope: `https://mail.google.com/`
  /// Pass [onRefreshToken] to renew expired access tokens automatically.
  factory EmailSmsService.gmailOAuth({
    required String email,
    required String accessToken,
    String? defaultCarrier,
    AccessTokenRefresh? onRefreshToken,
    SendOptions sendOptions = SendOptions.defaults,
  }) {
    return EmailSmsService(
      fromEmail: email,
      transport: SmtpEmailTransport.gmailOAuth(
        email: email,
        accessToken: accessToken,
        onRefreshToken: onRefreshToken,
        sendOptions: sendOptions,
      ),
      defaultCarrier: defaultCarrier,
    );
  }

  /// Gmail with a 16-digit App Password (legacy).
  ///
  /// Google rejects normal account passwords and discourages app passwords.
  @Deprecated('Use EmailSmsService.gmailOAuth')
  factory EmailSmsService.gmail({
    required String email,
    required String appPassword,
    String? defaultCarrier,
    SendOptions sendOptions = SendOptions.defaults,
  }) {
    return EmailSmsService(
      fromEmail: email,
      // ignore: deprecated_member_use_from_same_package
      transport: SmtpEmailTransport.gmail(
        email: email,
        appPassword: appPassword,
        sendOptions: sendOptions,
      ),
      defaultCarrier: defaultCarrier,
    );
  }

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

    final digits =
        PhoneNumber.forGateway(phoneNumber, countryCode: countryCode);
    if (!PhoneNumber.isPlausible(phoneNumber, countryCode: countryCode)) {
      return SmsResult.fail(
        'Invalid phone number: $phoneNumber',
        errorCode: SmsErrorCode.invalidNumber,
        segmentCount: segments,
      );
    }

    final resolvedCarrier = (carrier ?? defaultCarrier)?.trim();
    if (resolvedCarrier == null || resolvedCarrier.isEmpty) {
      return SmsResult.fail(
        'Carrier is required for email-to-SMS '
        '(e.g. att, verizon, tmobile). '
        'Supported: ${CarrierGateways.supportedCarriers.join(', ')}. '
        'Gateways are best-effort and may be retired by carriers.',
        errorCode: SmsErrorCode.carrierRequired,
        segmentCount: segments,
      );
    }

    final address = CarrierGateways.addressFor(
      phoneDigits: digits,
      carrier: resolvedCarrier,
    );
    if (address == null) {
      return SmsResult.fail(
        'Unknown carrier: $resolvedCarrier',
        errorCode: SmsErrorCode.unknownCarrier,
        segmentCount: segments,
      );
    }

    try {
      await transport.send(
        from: fromEmail,
        to: address,
        body: trimmed,
      );
      return SmsResult.ok(
        gatewayAddress: address,
        segmentCount: segments,
      );
    } catch (e) {
      if (isTimeoutError(e) || e is TimeoutException) {
        return SmsResult.fail(
          'SMTP send timed out: $e',
          errorCode: SmsErrorCode.timeout,
          gatewayAddress: address,
          segmentCount: segments,
        );
      }
      final text = e.toString();
      if (text.contains('Application-specific password') ||
          text.contains('InvalidSecondFactor') ||
          text.contains('Username and Password not accepted') ||
          text.contains('Invalid credentials') ||
          text.contains('535')) {
        return SmsResult.fail(
          'Gmail rejected the credentials. Google does not allow your normal '
          'account password for SMTP. Use Sign in with Google and pass an '
          'OAuth accessToken to EmailSmsService.gmailOAuth '
          '(scope: https://mail.google.com/), and provide onRefreshToken '
          'to renew expired tokens.',
          errorCode: SmsErrorCode.auth,
          gatewayAddress: address,
          segmentCount: segments,
        );
      }
      return SmsResult.fail(
        'SMTP send failed: $e',
        errorCode: SmsErrorCode.smtp,
        gatewayAddress: address,
        segmentCount: segments,
      );
    }
  }

  @override
  Future<bool> isServiceAvailable() async {
    if (fromEmail.trim().isEmpty) return false;
    return transport.isConfigured;
  }
}
