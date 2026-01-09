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

---

_Note: This is the stable 1.0.0 release. Future updates will include more carriers, improved reliability, and additional features based on community feedback._
