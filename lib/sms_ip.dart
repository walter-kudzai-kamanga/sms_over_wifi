library sms_over_wifi;

import 'package:sms_over_wifi/srs/email_sms_service.dart';

export 'srs/email_sms_service.dart';
export 'srs/web_sms_service.dart';
export 'srs/interfaces.dart';

/// Main class to initialize and use SMS over Wi-Fi services
class SmsOverWifi {
  /// Current package version
  static const String version = '2.0.0';
  
  static SmsService? _defaultService;
  static SmsServiceType _preferredService = SmsServiceType.email;

  /// Initialize the package with email configuration for email-to-SMS
  /// 
  /// For Gmail, you'll need an App Password (not your regular password)
  /// Enable 2FA and create an App Password at: https://myaccount.google.com/apppasswords
  static Future<void> initialize({
    String? email,
    String? password,
    String? smtpHost,
    int? smtpPort,
    bool sslEnabled = false,
    bool allowInsecure = false,
  }) async {
    if (email != null && password != null) {
      await EmailSmsService.initialize(
        email: email,
        password: password,
        smtpHost: smtpHost,
        smtpPort: smtpPort,
        sslEnabled: sslEnabled,
        allowInsecure: allowInsecure,
      );
      _defaultService = EmailSmsService();
      _preferredService = SmsServiceType.email;
    }
  }
  
  /// Initialize with web API key for web-based SMS services
  /// 
  /// Some free APIs like TextBelt have rate limits (1 SMS/day free tier)
  /// For production use, consider getting a paid API key
  static void initializeWeb({String? apiKey}) {
    _defaultService = WebSmsService(apiKey: apiKey);
    _preferredService = SmsServiceType.web;
  }
  
  /// Set preferred service type (email or web)
  static void setPreferredService(SmsServiceType serviceType) {
    _preferredService = serviceType;
    if (serviceType == SmsServiceType.email && _defaultService is! EmailSmsService) {
      _defaultService = EmailSmsService();
    } else if (serviceType == SmsServiceType.web && _defaultService is! WebSmsService) {
      _defaultService = WebSmsService();
    }
  }
  
  /// Get the current default service
  static SmsService? getDefaultService() {
    return _defaultService;
  }
  
  /// Send SMS using the default service
  /// 
  /// This method automatically uses the initialized service (email or web)
  /// Returns true if the message was sent successfully, false otherwise
  /// 
  /// Example:
  /// ```dart
  /// await SmsOverWifi.initialize(
  ///   email: 'your_email@gmail.com',
  ///   password: 'your_app_password',
  /// );
  /// 
  /// final success = await SmsOverWifi.sendSms(
  ///   phoneNumber: '+1234567890',
  ///   message: 'Hello from SMS Over WiFi!',
  ///   carrier: 'att', // Optional: specify carrier for email-to-SMS
  /// );
  /// ```
  static Future<bool> sendSms({
    required String phoneNumber,
    required String message,
    String? countryCode,
    String? carrier, // For email-to-SMS, specify carrier if known
  }) async {
    if (_defaultService == null) {
      throw Exception(
        'SMS service not initialized. Call initialize() or initializeWeb() first.',
      );
    }
    
    // If using email service and carrier is specified, ensure EmailSmsService is used
    if (carrier != null) {
      if (_defaultService is EmailSmsService) {
        // Pass carrier parameter to EmailSmsService
        final emailService = _defaultService as EmailSmsService;
        return await emailService.sendSms(
          phoneNumber: phoneNumber,
          message: message,
          countryCode: countryCode,
          carrier: carrier,
        );
      } else if (await EmailSmsService().isServiceAvailable()) {
        // Try to use EmailSmsService if available
        return await EmailSmsService().sendSms(
          phoneNumber: phoneNumber,
          message: message,
          countryCode: countryCode,
          carrier: carrier,
        );
      }
    }
    
    return await _defaultService!.sendSms(
      phoneNumber: phoneNumber,
      message: message,
      countryCode: countryCode,
    );
  }
  
  /// Send SMS to multiple recipients
  /// 
  /// Returns a map of phone numbers to success status
  static Future<Map<String, bool>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    String? countryCode,
  }) async {
    if (_defaultService == null) {
      throw Exception(
        'SMS service not initialized. Call initialize() or initializeWeb() first.',
      );
    }
    
    return await _defaultService!.sendBulkSms(
      phoneNumbers: phoneNumbers,
      message: message,
      countryCode: countryCode,
    );
  }
  
  /// Check if the SMS service is available
  static Future<bool> isServiceAvailable() async {
    if (_defaultService == null) {
      return false;
    }
    return await _defaultService!.isServiceAvailable();
  }
}
