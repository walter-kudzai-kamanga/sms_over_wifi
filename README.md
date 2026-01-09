# sms_over_wifi

A Flutter package to send SMS messages over Wi-Fi without a SIM card.

[![pub package](https://img.shields.io/pub/v/sms_over_wifi.svg)](https://pub.dev/packages/sms_over_wifi)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Getting started

Add this package to your `pubspec.yaml`:

````yaml
dependencies:
  sms_over_wifi: ^0.0.1
## Getting started


Import the package:

```dart
import 'package:sms_over_wifi/sms_over_wifi.dart';
````

## Quick example

Here's a minimal example — adjust to your package API if names differ:

```dart
import 'package:flutter/material.dart';
import 'package:sms_over_wifi/sms_over_wifi.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text('SMS Over Wi-Fi Demo')),
        body: Center(
          child: ElevatedButton(
            onPressed: () async {
              // Initialize email service
              await SmsOverWifi.initialize(
                email: 'your_email@gmail.com',
                password: 'your_app_password',
              );

              // Send SMS
              final smsService = EmailSmsService();
              final success = await smsService.sendSms(
                phoneNumber: '+1234567890',
                message: 'Hello from SMS Over Wi-Fi!',
                countryCode: 'US',
              );

              if (success) {
                print('SMS sent successfully!');
              } else {
                print('Failed to send SMS');
              }
            },
            child: Text('Send SMS Over Wi-Fi'),
          ),
        ),
      ),
    );
  }
}
```

## Features

- Send SMS messages using Wi-Fi connection only
- No SIM card required
- Multiple delivery methods (Email-to-SMS, Web APIs)
- Free to use with rate limits
- Platform independent (Android, iOS, Web)
- Customizable carrier gateways
- Bulk SMS sending support
- Carrier detection support

## Public API (summary)

- SmsOverWifi — main class for package initialization
- EmailSmsService — sends SMS via email-to-SMS gateways
- WebSmsService — sends SMS via free web APIs
- SmsService — interface for all SMS services

Common methods: sendSms(), sendBulkSms(), isServiceAvailable()

## Contributing

- Fork the repo and open a branch for your change.
- Add tests where relevant and ensure `flutter test` passes.
- Follow semantic versioning for public API changes.

## Changelog

## License

This project is licensed under the MIT License — see the LICENSE file for details.
