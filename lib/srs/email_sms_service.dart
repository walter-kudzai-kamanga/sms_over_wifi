import 'dart:async';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'interfaces.dart';

/// Service that sends SMS using email-to-SMS gateways
class EmailSmsService implements SmsService {
  static final EmailSmsService _instance = EmailSmsService._internal();
  factory EmailSmsService() => _instance;
  EmailSmsService._internal();

  static String? _email;
  static String? _password;
  static SmtpServer? _smtpServer;

  /// Email-to-SMS gateways for different carriers
  static const Map<String, String> _carrierGateways = {
    // USA Carriers
    'att': 'txt.att.net',
    'verizon': 'vtext.com',
    'tmobile': 'tmomail.net',
    'sprint': 'messaging.sprintpcs.com',
    'boost': 'smsmyboostmobile.com',
    'cricket': 'sms.cricketwireless.net',
    'metro': 'mymetropcs.com',
    'uscellular': 'email.uscc.net',
    'virgin': 'vmobl.com',
    'googlefi': 'msg.fi.google.com',

    // Canada Carriers
    'rogers': 'pcs.rogers.com',
    'bell': 'txt.bell.ca',
    'telus': 'msg.telus.com',
    'fido': 'fido.ca',
    'virgincanada': 'vmobile.ca',

    // UK Carriers
    'vodafone': 'vodafone.net',
    'o2': 'o2.co.uk',
    'ee': 'mms.ee.co.uk',
    'three': 'three.co.uk',
  };

  /// Initialize with email credentials
  /// [smtpHost] and [smtpPort] are optional and will be auto-detected from email domain
  /// Common providers: Gmail (smtp.gmail.com:587), Outlook (smtp-mail.outlook.com:587)
  static Future<void> initialize({
    required String email,
    required String password,
    String? smtpHost,
    int? smtpPort,
    bool sslEnabled = false,
    bool allowInsecure = false,
  }) async {
    _email = email;
    _password = password;
    
    // Auto-detect SMTP server based on email domain if not provided
    if (smtpHost == null) {
      final domain = email.split('@').last.toLowerCase();
      smtpHost = _getSmtpHost(domain);
      smtpPort = smtpPort ?? _getSmtpPort(domain);
      sslEnabled = _getSslEnabled(domain);
    }
    
    if (smtpHost != null) {
      if (smtpHost.contains('gmail')) {
        _smtpServer = gmail(email, password);
      } else if (smtpHost.contains('outlook') || smtpHost.contains('hotmail') || smtpHost.contains('live')) {
        _smtpServer = hotmail(email, password);
      } else {
        _smtpServer = SmtpServer(
          smtpHost,
          port: smtpPort ?? (sslEnabled ? 465 : 587),
          ssl: sslEnabled,
          allowInsecure: allowInsecure,
          username: email,
          password: password,
        );
      }
    }
    // Note: In production, use secure storage like flutter_secure_storage
  }
  
  String? _getSmtpHost(String domain) {
    switch (domain) {
      case 'gmail.com':
        return 'smtp.gmail.com';
      case 'outlook.com':
      case 'hotmail.com':
      case 'live.com':
        return 'smtp-mail.outlook.com';
      case 'yahoo.com':
        return 'smtp.mail.yahoo.com';
      case 'icloud.com':
      case 'me.com':
        return 'smtp.mail.me.com';
      default:
        return 'smtp.$domain';
    }
  }
  
  int _getSmtpPort(String domain) {
    switch (domain) {
      case 'gmail.com':
      case 'outlook.com':
      case 'hotmail.com':
      case 'live.com':
        return 587;
      default:
        return 587;
    }
  }
  
  bool _getSslEnabled(String domain) {
    switch (domain) {
      case 'gmail.com':
      case 'outlook.com':
      case 'hotmail.com':
      case 'live.com':
        return false; // Use STARTTLS
      default:
        return false;
    }
  }

  @override
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
    String? countryCode = 'US',
    String? carrier, // Optional: specify carrier directly
  }) async {
    try {
      if (_email == null || _password == null) {
        throw Exception(
            'Email service not initialized. Call initialize() first.');
      }

      // Clean phone number
      final cleanNumber = _cleanPhoneNumber(phoneNumber);

      // Determine carrier - use provided carrier or detect
      String? carrierKey = carrier?.toLowerCase();
      
      if (carrierKey == null || !_carrierGateways.containsKey(carrierKey)) {
        carrierKey = await _detectCarrier(cleanNumber, countryCode);
      }

      if (carrierKey == null || !_carrierGateways.containsKey(carrierKey)) {
        throw Exception('Could not determine carrier for $cleanNumber. Please specify carrier.');
      }

      final gateway = _carrierGateways[carrierKey];
      if (gateway == null) {
        throw Exception('Carrier gateway not found for $carrierKey');
      }

      // Send email via SMTP
      final result = await _sendEmailViaSmtp(
        to: '$cleanNumber@$gateway',
        subject: '',
        body: message,
      );

      return result;
    } catch (e) {
      print('Error in sendSms: $e');
      return false;
    }
  }
  
  /// Get list of supported carriers
  static List<String> getSupportedCarriers() {
    return _carrierGateways.keys.toList();
  }
  
  /// Get gateway for a specific carrier
  static String? getGatewayForCarrier(String carrier) {
    return _carrierGateways[carrier.toLowerCase()];
  }

  @override
  Future<Map<String, bool>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    String? countryCode,
  }) async {
    final results = <String, bool>{};

    for (final number in phoneNumbers) {
      try {
        final success = await sendSms(
          phoneNumber: number,
          message: message,
          countryCode: countryCode,
        );
        results[number] = success;
      } catch (e) {
        results[number] = false;
      }

      // Delay between messages to avoid rate limiting
      await Future.delayed(const Duration(seconds: 1));
    }

    return results;
  }

  @override
  Future<bool> isServiceAvailable() async {
    return _email != null && _password != null;
  }

  String _cleanPhoneNumber(String phoneNumber) {
    // Remove all non-numeric characters
    return phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
  }

  Future<String?> _detectCarrier(
      String phoneNumber, String? countryCode) async {
    // This is a simplified implementation
    // In production, you might use a carrier lookup API or
    // let users specify their carrier

    // Default to US carriers
    return 'att'; // or implement carrier detection logic
  }

  Future<bool> _sendEmailViaSmtp({
    required String to,
    required String subject,
    required String body,
  }) async {
    try {
      if (_email == null || _password == null) {
        throw Exception('Email service not initialized. Call initialize() first.');
      }
      
      if (_smtpServer == null) {
        throw Exception('SMTP server not configured. Ensure initialize() was called with valid credentials.');
      }

      final message = Message()
        ..from = Address(_email!, 'SMS Over WiFi')
        ..recipients.add(to)
        ..subject = subject.isNotEmpty ? subject : 'SMS Message'
        ..text = body
        ..headers = {
          'X-Mailer': 'sms_over_wifi',
        };

      final sendReport = await send(message, _smtpServer!);
      
      // Check if email was sent successfully
      return sendReport.toString().contains('Message sent') ||
             !sendReport.toString().toLowerCase().contains('error');
    } catch (e) {
      print('Error sending email via SMTP: $e');
      return false;
    }
  }
}
