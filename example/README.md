# Examples

## CLI (Twilio)

```sh
export TWILIO_ACCOUNT_SID=ACxxxxxxxx
export TWILIO_AUTH_TOKEN=your_auth_token
export TWILIO_FROM_NUMBER=+15017122661
export SMS_TO=+263782926585

dart run example/sms_over_wifi_example.dart
```

## Flutter host (Gmail OAuth email-to-SMS)

In your Flutter app:

```yaml
dependencies:
  sms_over_wifi: ^1.3.0
  google_sign_in: ^6.2.1
```

```dart
final googleSignIn = GoogleSignIn(
  scopes: [SmsOverWifi.gmailMailScope],
);

Future<String?> refresh() async {
  final account = googleSignIn.currentUser ?? await googleSignIn.signInSilently();
  final auth = await account?.authentication;
  return auth?.accessToken;
}

final account = await googleSignIn.signIn();
final auth = await account!.authentication;

await SmsOverWifi.initialize(
  email: account.email,
  accessToken: auth.accessToken!,
  defaultCarrier: 'att', // US/CA/UK gateways only — best-effort
  onAccessTokenRefresh: refresh,
);

final result = await SmsOverWifi.sendSms(
  phoneNumber: '+15551234567',
  message: 'Hello over Wi-Fi',
  carrier: 'att',
);
```

For worldwide delivery (including Zimbabwe), use Twilio instead of email gateways.
