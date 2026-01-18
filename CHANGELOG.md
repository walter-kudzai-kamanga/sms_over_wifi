# Changelog

All notable changes to this project will be documented in this file.

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-09

### Added

- Initial release of `sms_over_wifi` package
- `SmsOverWifi` main class for package initialization
- `EmailSmsService` for sending SMS via email-to-SMS gateways
- `WebSmsService` for sending SMS via free web APIs
- `SmsService` interface with common SMS operations
- Support for multiple carrier gateways (AT&T, Verizon, T-Mobile, Sprint, etc.)
- Bulk SMS sending capability
- Carrier detection support
- Platform independence (Android, iOS, Web)
- Free tier with rate-limited services
- No SIM card required - works over Wi-Fi only
- Example application in `example/` directory
- Comprehensive README documentation
- MIT license with legal compliance notices

### Features

- Single SMS sending with `sendSms()` method
- Bulk SMS sending with `sendBulkSms()` method
- Service availability checking
- International number support with country codes
- Email-to-SMS gateway configuration
- Web API fallback mechanism
- Error handling and status reporting
- Customizable carrier gateways
- Rate limiting and delay between messages
- Secure credential storage recommendations

### Technical Details

- Built with Flutter SDK compatibility
- HTTP client integration for web APIs
- Platform channel support for native email sending
- Modular service architecture
- Extensible interface for custom implementations
- No external dependencies for core functionality
- Full Dart null safety compliance
- Documentation comments throughout codebase

### Initial Carrier Support

- **USA Carriers**: AT&T, Verizon, T-Mobile, Sprint, Boost, Cricket, Metro, US Cellular, Virgin, Google Fi
- **Canada Carriers**: Rogers, Bell, Telus, Fido, Virgin Mobile Canada
- **UK Carriers**: Vodafone, O2, EE, Three

### Legal Compliance

- TCPA compliance guidelines
- Anti-spam regulations notice
- Carrier terms of service compliance
- User consent requirements documentation
- Privacy considerations for message content

### Fixed

- Removed unused imports in `email_sms_service.dart`
- Fixed asset directory reference in `pubspec.yaml`
- Replaced `print` statements with proper logging pattern

## [2.0.0] - 2026-01-09

### Added

- **Actual SMS sending functionality** - The package now actually sends SMS messages over WiFi
- Real SMTP email sending using the `mailer` package
- Enhanced `SmsOverWifi.sendSms()` method for easy message sending
- Support for multiple email providers (Gmail, Outlook, Yahoo, iCloud, custom SMTP)
- Improved error handling and logging
- Automatic SMTP server detection based on email domain
- Web API quota checking functionality
- Service preference configuration
- Better API response handling for web services

### Changed

- **Breaking**: `EmailSmsService.initialize()` now requires actual SMTP configuration
- `EmailSmsService` now uses real SMTP email sending instead of placeholder
- `WebSmsService` has improved error handling and response parsing
- `SmsOverWifi` main class now provides convenient `sendSms()` and `sendBulkSms()` methods
- Version updated to 2.0.0 to reflect actual working functionality

### Enhanced

- Email-to-SMS service now actually sends emails via SMTP
- Web SMS service has better error messages and status reporting
- Automatic fallback between services when one is unavailable
- Improved carrier gateway detection
- Better phone number cleaning and validation

### Technical Improvements

- Added `mailer` package dependency for SMTP support
- SMTP server auto-configuration for popular email providers
- Support for STARTTLS and SSL/TLS connections
- Enhanced error messages for debugging
- Better HTTP response handling for web APIs

### Migration Guide

If you're upgrading from 1.0.0 to 2.0.0:

1. **For Email-to-SMS**: Ensure you have a valid email account with SMTP access. For Gmail, you'll need an App Password (not your regular password).

2. **Initialization**: The initialization process now actually configures SMTP servers. You may need to provide additional SMTP parameters for custom email providers.

3. **New API**: You can now use `SmsOverWifi.sendSms()` directly without instantiating services manually.

Example migration:
```dart
// Old way (still works)
await SmsOverWifi.initialize(email: 'user@gmail.com', password: 'app_password');
final service = EmailSmsService();
await service.sendSms(phoneNumber: '+1234567890', message: 'Hello');

// New way (recommended)
await SmsOverWifi.initialize(email: 'user@gmail.com', password: 'app_password');
await SmsOverWifi.sendSms(phoneNumber: '+1234567890', message: 'Hello');
```

---

_Note: Version 2.0.0 introduces actual working SMS sending functionality. Make sure to use proper credentials and follow your email provider's requirements (e.g., Gmail App Passwords)._
