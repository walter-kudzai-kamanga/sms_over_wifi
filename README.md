# sms_over_wifi

Send SMS over Wi-Fi — no SIM card.

**For most countries (including Zimbabwe), use Twilio.** One initialize + one send.

Email-to-SMS carrier gateways are **best-effort** (US/CA/UK only) and may stop working when carriers retire them.

## Install

```yaml
dependencies:
  sms_over_wifi: ^1.3.0
```

Pure Dart — works in Flutter apps, CLI tools, and servers.

```dart
import 'package:sms_over_wifi/sms_over_wifi.dart';
```

## Quick start (Twilio — recommended)

1. Create a free trial at [twilio.com](https://www.twilio.com/try-twilio)
2. Copy **Account SID**, **Auth Token**, and buy/get a **Twilio phone number**
3. On a trial account, verify the destination number in the Twilio console

```dart
await SmsOverWifi.initialize(
  twilioAccountSid: 'ACxxxxxxxx',
  twilioAuthToken: 'your_auth_token',
  twilioFromNumber: '+15017122661',
);

final result = await SmsOverWifi.sendSms(
  phoneNumber: '+263782926585',
  message: 'Hello over Wi-Fi via Twilio',
);

print(result.success
    ? 'Sent ${result.gatewayAddress} (${result.segmentCount} segments)'
    : '${result.errorCode}: ${result.error}');
```

Or without the facade:

```dart
final sms = TwilioSmsService(
  accountSid: 'ACxxxxxxxx',
  authToken: 'your_auth_token',
  fromNumber: '+15017122661',
);

await sms.sendSms(phoneNumber: '+263782926585', message: 'Hi');
```

Store credentials in env / secure storage — never commit them.

## Gmail OAuth email-to-SMS (US/CA/UK)

Google blocks normal Gmail passwords for SMTP. Use Sign in with Google and pass a refresh callback so expired tokens renew automatically:

```dart
await SmsOverWifi.initialize(
  email: account.email,
  accessToken: auth.accessToken!,
  defaultCarrier: 'att',
  onAccessTokenRefresh: () async {
    final auth = await account.authentication;
    return auth.accessToken;
  },
);

await SmsOverWifi.sendSms(
  phoneNumber: '+15551234567',
  message: 'Hello',
  carrier: 'verizon',
);
```

Host apps should depend on `google_sign_in` and request `SmsOverWifi.gmailMailScope`.

## Textbelt / custom HTTP

```dart
final sms = WebSmsService(apiKey: 'your_paid_key');
await sms.sendSms(phoneNumber: '+15551234567', message: 'Hi');

// Custom JSON API
final custom = WebSmsService(
  apiKey: 'secret',
  provider: JsonSmsProvider(
    name: 'my-api',
    endpoint: Uri.parse('https://sms.example.com/send'),
  ),
);
```

## Backends

| Backend | When to use |
|---------|-------------|
| **Twilio** | Worldwide SMS — simplest, most reliable |
| **Gmail OAuth email-to-SMS** | US/CA/UK carriers with public gateways only |
| **Textbelt / JsonSmsProvider** | Paid HTTP APIs; free Textbelt is limited |

## API

| Type | Role |
|------|------|
| `SmsOverWifi` | Shared `initialize` / `sendSms` |
| `TwilioSmsService` | Twilio REST API |
| `EmailSmsService.gmailOAuth` | Gmail XOAUTH2 → carrier gateway |
| `WebSmsService` | Pluggable HTTP SMS (`WebSmsProvider`) |
| `SmsResult` | `success`, `error`, `errorCode`, `gatewayAddress`, `segmentCount` |
| `SendOptions` | Timeouts + retries |
| `CarrierGateways` | Gateway domains + aliases |

## Notes

- Do **not** pass your Gmail login password.
- Carrier must be known for the email path; aliases like `vzw` → `verizon` are supported.
- `SmsResult.segmentCount` estimates GSM/Unicode segments (advisory).
- Comply with local messaging laws and get recipient consent.

## Example

See [`example/`](example/) for a Twilio CLI sample and Flutter Gmail OAuth notes.

## License

MIT — see [LICENSE](LICENSE).
