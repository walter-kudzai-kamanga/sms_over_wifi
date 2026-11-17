import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

import 'retry.dart';

/// Supplies a fresh Gmail OAuth access token when the current one expires.
typedef AccessTokenRefresh = Future<String?> Function();

/// Abstraction so email delivery can be swapped (SMTP, mocks, HTTP relays).
abstract class EmailTransport {
  Future<void> send({
    required String from,
    required String to,
    required String body,
    String subject = '',
  });

  /// Whether credentials look present enough to attempt a send.
  Future<bool> get isConfigured async => true;
}

/// Real SMTP transport using the `mailer` package (Wi-Fi / internet path).
class SmtpEmailTransport implements EmailTransport {
  SmtpServer Function() _serverFactory;
  final AccessTokenRefresh? _onRefreshToken;
  final String? _oauthEmail;
  String? _oauthAccessToken;
  final SendOptions sendOptions;

  SmtpEmailTransport._(
    this._serverFactory, {
    AccessTokenRefresh? onRefreshToken,
    String? oauthEmail,
    String? oauthAccessToken,
    this.sendOptions = SendOptions.defaults,
  })  : _onRefreshToken = onRefreshToken,
        _oauthEmail = oauthEmail,
        _oauthAccessToken = oauthAccessToken;

  /// Generic username/password SMTP (non-Gmail providers, or Gmail app password).
  ///
  /// Gmail **account** passwords are rejected by Google. Prefer
  /// [SmtpEmailTransport.gmailOAuth].
  factory SmtpEmailTransport({
    required String username,
    required String password,
    String host = 'smtp.gmail.com',
    int port = 465,
    bool ssl = true,
    bool allowInsecure = false,
    SendOptions sendOptions = SendOptions.defaults,
  }) {
    return SmtpEmailTransport._(
      () => SmtpServer(
        host,
        port: port,
        ssl: ssl,
        username: username,
        password: password,
        allowInsecure: allowInsecure,
      ),
      sendOptions: sendOptions,
    );
  }

  /// Gmail via **Sign in with Google** (XOAUTH2) — Google's recommended path.
  ///
  /// [accessToken] must include scope `https://mail.google.com/`.
  /// Pass [onRefreshToken] so expired tokens can be renewed without re-login.
  factory SmtpEmailTransport.gmailOAuth({
    required String email,
    required String accessToken,
    AccessTokenRefresh? onRefreshToken,
    SendOptions sendOptions = SendOptions.defaults,
  }) {
    late SmtpEmailTransport transport;
    transport = SmtpEmailTransport._(
      () => gmailSaslXoauth2(email, transport._oauthAccessToken ?? accessToken),
      onRefreshToken: onRefreshToken,
      oauthEmail: email,
      oauthAccessToken: accessToken,
      sendOptions: sendOptions,
    );
    return transport;
  }

  /// Gmail with a 16-digit **App Password** (legacy; Google discourages this).
  @Deprecated(
    'Use SmtpEmailTransport.gmailOAuth — Google blocks account passwords',
  )
  factory SmtpEmailTransport.gmail({
    required String email,
    required String appPassword,
    SendOptions sendOptions = SendOptions.defaults,
  }) {
    return SmtpEmailTransport(
      username: email,
      password: appPassword,
      host: 'smtp.gmail.com',
      port: 465,
      ssl: true,
      sendOptions: sendOptions,
    );
  }

  @override
  Future<bool> get isConfigured async {
    if (_oauthEmail != null) {
      return _oauthEmail!.isNotEmpty &&
          (_oauthAccessToken != null && _oauthAccessToken!.isNotEmpty);
    }
    return true;
  }

  bool _isAuthFailure(Object error) {
    final text = error.toString();
    return text.contains('Application-specific password') ||
        text.contains('InvalidSecondFactor') ||
        text.contains('Username and Password not accepted') ||
        text.contains('Invalid credentials') ||
        text.contains('535') ||
        text.contains('Authentication');
  }

  Future<void> _sendOnce({
    required String from,
    required String to,
    required String body,
    required String subject,
  }) async {
    final message = mailer.Message()
      ..from = mailer.Address(from)
      ..recipients.add(to)
      ..subject = subject
      ..text = body;

    await mailer.send(message, _serverFactory());
  }

  @override
  Future<void> send({
    required String from,
    required String to,
    required String body,
    String subject = '',
  }) async {
    try {
      await withRetries(
        () => _sendOnce(from: from, to: to, body: body, subject: subject),
        options: sendOptions,
        retryIf: (e) => isTimeoutError(e) || !_isAuthFailure(e),
      );
    } catch (e) {
      if (_isAuthFailure(e) && _onRefreshToken != null) {
        final refreshed = await _onRefreshToken!();
        if (refreshed != null && refreshed.isNotEmpty) {
          _oauthAccessToken = refreshed;
          await withRetries(
            () => _sendOnce(from: from, to: to, body: body, subject: subject),
            options: sendOptions,
            retryIf: isTimeoutError,
          );
          return;
        }
      }
      rethrow;
    }
  }
}
