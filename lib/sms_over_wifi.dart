import 'src/email_sms_service.dart';
import 'src/email_transport.dart';
import 'src/interfaces.dart';
import 'src/retry.dart';
import 'src/twilio_sms_service.dart';
import 'src/web_sms_service.dart';

export 'src/carriers.dart';
export 'src/email_sms_service.dart';
export 'src/email_transport.dart';
export 'src/interfaces.dart';
export 'src/phone.dart';
export 'src/retry.dart';
export 'src/segments.dart';
export 'src/twilio_sms_service.dart';
export 'src/web_sms_provider.dart';
export 'src/web_sms_service.dart';

/// Entry point for SMS-over-Wi-Fi delivery.
///
/// Prefer [TwilioSmsService] for reliable worldwide delivery (including
/// Zimbabwe). Use [SmsOverWifi.initialize] for a shared default service.
class SmsOverWifi {
  static const String version = '1.3.0';

  /// OAuth scope required for Gmail SMTP (XOAUTH2).
  static const String gmailMailScope = 'https://mail.google.com/';

  static SmsService? _service;

  /// Active service after [initialize], if any.
  static SmsService? get service => _service;

  /// Configure a shared default backend.
  ///
  /// **Twilio (recommended for worldwide SMS):** pass [twilioAccountSid],
  /// [twilioAuthToken], and [twilioFromNumber].
  ///
  /// **Gmail email-to-SMS:** [email] + [accessToken] (US/CA/UK carriers only).
  /// Pass [onAccessTokenRefresh] so expired Gmail tokens can be renewed.
  ///
  /// **Textbelt / custom HTTP:** [webApiKey] / [preferWeb].
  static Future<SmsService> initialize({
    String? twilioAccountSid,
    String? twilioAuthToken,
    String? twilioFromNumber,
    String? email,
    String? accessToken,
    AccessTokenRefresh? onAccessTokenRefresh,
    String? password,
    String? defaultCarrier,
    String smtpHost = 'smtp.gmail.com',
    int smtpPort = 465,
    bool smtpSsl = true,
    String? webApiKey,
    bool preferWeb = false,
    SendOptions sendOptions = SendOptions.defaults,
  }) async {
    if (twilioAccountSid != null &&
        twilioAuthToken != null &&
        twilioFromNumber != null) {
      _service = TwilioSmsService(
        accountSid: twilioAccountSid,
        authToken: twilioAuthToken,
        fromNumber: twilioFromNumber,
        sendOptions: sendOptions,
      );
      return _service!;
    }

    if (preferWeb || (email == null && webApiKey != null)) {
      _service = WebSmsService(
        apiKey: webApiKey ?? 'textbelt',
        sendOptions: sendOptions,
      );
      return _service!;
    }

    if (email != null && accessToken != null && accessToken.isNotEmpty) {
      _service = EmailSmsService.gmailOAuth(
        email: email,
        accessToken: accessToken,
        defaultCarrier: defaultCarrier,
        onRefreshToken: onAccessTokenRefresh,
        sendOptions: sendOptions,
      );
      return _service!;
    }

    if (email != null && password != null) {
      if (smtpHost == 'smtp.gmail.com') {
        // ignore: deprecated_member_use_from_same_package
        _service = EmailSmsService.gmail(
          email: email,
          appPassword: password,
          defaultCarrier: defaultCarrier,
          sendOptions: sendOptions,
        );
      } else {
        _service = EmailSmsService(
          fromEmail: email,
          defaultCarrier: defaultCarrier,
          transport: SmtpEmailTransport(
            username: email,
            password: password,
            host: smtpHost,
            port: smtpPort,
            ssl: smtpSsl,
            sendOptions: sendOptions,
          ),
        );
      }
      return _service!;
    }

    throw ArgumentError(
      'Easiest path: pass twilioAccountSid + twilioAuthToken + twilioFromNumber. '
      'Or Gmail OAuth (email + accessToken, optional onAccessTokenRefresh), '
      'or webApiKey for Textbelt.',
    );
  }

  /// Send via the service created by [initialize].
  static Future<SmsResult> sendSms({
    required String phoneNumber,
    required String message,
    String? countryCode,
    String? carrier,
  }) {
    final active = _service;
    if (active == null) {
      return Future.value(
        SmsResult.fail(
          'Call SmsOverWifi.initialize(...) before sendSms.',
          errorCode: SmsErrorCode.notInitialized,
        ),
      );
    }
    return active.sendSms(
      phoneNumber: phoneNumber,
      message: message,
      countryCode: countryCode,
      carrier: carrier,
    );
  }

  /// Clears the shared service (useful in tests).
  static void reset() => _service = null;
}
