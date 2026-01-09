import 'dart:convert';
import 'package:http/http.dart' as http;
import 'interfaces.dart';

/// Service that uses free web-based SMS APIs
class WebSmsService implements SmsService {
  final List<String> _freeApis = [
    'https://textbelt.com/text', // Free tier available
    // Add other free APIs as they become available
  ];

  @override
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
    String? countryCode,
  }) async {
    for (final api in _freeApis) {
      try {
        final response = await http.post(
          Uri.parse(api),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone': phoneNumber,
            'message': message,
            'key': 'textbelt', // Some APIs require keys
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['success'] == true;
        }
      } catch (e) {
        continue; // Try next API
      }
    }

    return false;
  }

  @override
  Future<Map<String, bool>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    String? countryCode,
  }) async {
    final results = <String, bool>{};

    for (final number in phoneNumbers) {
      results[number] = await sendSms(
        phoneNumber: number,
        message: message,
        countryCode: countryCode,
      );
      await Future.delayed(const Duration(seconds: 1));
    }

    return results;
  }

  @override
  Future<bool> isServiceAvailable() async {
    try {
      // Test connection to APIs
      final response = await http.get(Uri.parse(_freeApis.first));
      return response.statusCode < 500;
    } catch (e) {
      return false;
    }
  }
}
