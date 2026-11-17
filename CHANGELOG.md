# Changelog

All notable changes to this project will be documented in this file.

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-11-17

Finalized release for worldwide SMS over Wi-Fi.

### Verified

- `dart analyze --fatal-infos` — clean
- `dart test` — **27/27** passed (phone, carriers, segments, email, web, Twilio, facade, retries)
- Line coverage ≈ **65%** of `lib/` (unit mocks; no live network credentials required)

### Added

- `TwilioSmsService` for worldwide SMS over Wi-Fi (including Zimbabwe)
- `SmsOverWifi.initialize(twilioAccountSid:, twilioAuthToken:, twilioFromNumber:)`
- OAuth access-token refresh via `onRefreshToken` / `onAccessTokenRefresh`
- `SendOptions` + `withRetries` (timeouts and limited retries) for SMTP/HTTP
- `SmsErrorCode` on `SmsResult` (`auth`, `quota`, `timeout`, `smtp`, `http`, …)
- `SmsResult.segmentCount` / `SmsSegments` GSM vs Unicode estimates
- Pluggable `WebSmsProvider` (`TextbeltProvider`, `JsonSmsProvider`)
- Carrier aliases (`vzw` → `verizon`, etc.) on `CarrierGateways`
- E.164 helpers via `phone_numbers_parser`
- Shared `SmsServiceBase` bulk-send implementation
- Honest availability probes (Twilio account GET, Textbelt quota)
- Example CLI + GitHub Actions CI (`dart analyze` / `dart test`)

### Changed

- Package is **pure Dart** (no Flutter SDK dependency) — usable from Flutter, CLI, and servers
- Twilio is the recommended path for international delivery
- Removed unused `SmsConfig` / `SmsMessage` / `SmsServiceType` types
- Phone normalization uses proper parsing with country context on web/Twilio paths
- Document email-to-SMS gateways as best-effort / often retired by carriers
- Dropped unnecessary library name declaration (CI `--fatal-infos` clean)

## [1.2.0] - 2026-11-17

### Added

- `EmailSmsService.gmailOAuth` / `SmtpEmailTransport.gmailOAuth` (Gmail XOAUTH2)
- `SmsOverWifi.initialize(accessToken: ...)` for Sign in with Google
- `SmsOverWifi.gmailMailScope` (`https://mail.google.com/`)
- Clear error when Gmail rejects a normal account password

### Changed

- Prefer OAuth over App Passwords; document that Google blocks account passwords

## [1.1.0] - 2026-11-17

### Changed

- Real SMTP delivery via `mailer` (`SmtpEmailTransport`) instead of a stub that always returned success
- Package entry point is now `lib/sms_over_wifi.dart` (was `sms_ip.dart`)
- Source lives under `lib/src/` (was misspelled `srs/`)
- `sendSms` returns `SmsResult` with success/error/gateway details
- Carrier is required for email-to-SMS (removed fake “always AT&T” detection)
- Bulk delay default shortened from 1s to 100ms (configurable, skippable)
- Removed unused `dio` dependency
- Dropped static singleton credential storage in favor of instance config

### Added

- Injectable `EmailTransport` for testing and custom relays
- `PhoneNumber` helpers and `CarrierGateways` lookup
- Deterministic unit tests with mock HTTP / recording SMTP transport

## [1.0.0] - 2026-01-09

### Added

- Initial release scaffolding for email-to-SMS and web SMS services
