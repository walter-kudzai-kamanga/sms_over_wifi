import 'dart:convert';
import 'package:http/http.dart' as http;
import 'interfaces.dart';

/// Service that uses free web-based SMS APIs
class WebSmsService implements SmsService {
  final String? _apiKey;
  
  // Free SMS API endpoints (these may have rate limits)
  static const String _textBeltApi = 'https://textbelt.com/text';
  static const String _textBeltQuotaApi = 'https://textbelt.com/quota';
  
  WebSmsService({String? apiKey}) : _apiKey = apiKey;

  @override
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
    String? countryCode,
  }) async {
    // Clean phone number (remove any non-numeric characters except +)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    try {
      // Try TextBelt API first (free tier with 1 SMS per day)
      final response = await http.post(
        Uri.parse(_textBeltApi),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'phone': cleanNumber,
          'message': message,
          'key': _apiKey ?? 'textbelt', // Use provided key or default
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return true;
        } else {
          print('SMS sending failed: ${data['error'] ?? 'Unknown error'}');
          return false;
        }
      } else if (response.statusCode == 400) {
        // Bad request - likely invalid phone number or quota exceeded
        final data = jsonDecode(response.body);
        print('Bad request: ${data['error'] ?? response.body}');
        return false;
      } else {
        print('HTTP error: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error sending SMS via web API: $e');
      return false;
    }
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
      // Check quota endpoint to verify service availability
      final response = await http.get(
        Uri.parse('$_textBeltQuotaApi/${_apiKey ?? 'textbelt'}'),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Service is available if we get a valid response
        return data['success'] != false;
      }
      return false;
    } catch (e) {
      // If quota check fails, try a simple connectivity test
      try {
        final response = await http.head(Uri.parse(_textBeltApi)).timeout(
          const Duration(seconds: 5),
        );
        return response.statusCode < 500;
      } catch (_) {
        return false;
      }
    }
  }
  
  /// Get remaining quota for TextBelt API (if using API key)
  Future<int?> getQuota() async {
    if (_apiKey == null) return null;
    
    try {
      final response = await http.get(
        Uri.parse('$_textBeltQuotaApi/$_apiKey'),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['quotaRemaining'] as int?;
        }
      }
    } catch (e) {
      print('Error checking quota: $e');
    }
    return null;
  }
}
