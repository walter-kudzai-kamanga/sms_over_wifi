/// Interface for SMS services
abstract class SmsService {
  /// Send SMS to a single recipient
  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
    String? countryCode,
  });

  /// Send SMS to multiple recipients
  Future<Map<String, bool>> sendBulkSms({
    required List<String> phoneNumbers,
    required String message,
    String? countryCode,
  });

  /// Check if service is available
  Future<bool> isServiceAvailable();
}

/// SMS Service types
enum SmsServiceType {
  email, // Using email-to-SMS gateways
  web, // Using web-based SMS services
  custom, // Custom implementation
}

/// Configuration for SMS service
class SmsConfig {
  final SmsServiceType serviceType;
  final Map<String, dynamic> credentials;

  SmsConfig({
    required this.serviceType,
    required this.credentials,
  });
}

/// SMS Message model
class SmsMessage {
  final String id;
  final String phoneNumber;
  final String message;
  final DateTime timestamp;
  final bool isSent;
  final String? error;

  SmsMessage({
    required this.phoneNumber,
    required this.message,
    this.id = '',
    DateTime? timestamp,
    this.isSent = false,
    this.error,
  }) : timestamp = timestamp ?? DateTime.now();

  SmsMessage copyWith({
    String? id,
    String? phoneNumber,
    String? message,
    DateTime? timestamp,
    bool? isSent,
    String? error,
  }) {
    return SmsMessage(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isSent: isSent ?? this.isSent,
      error: error ?? this.error,
    );
  }
}
