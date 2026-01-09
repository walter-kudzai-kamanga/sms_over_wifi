library sms_over_wifi;

import 'package:sms_over_wifi/srs/email_sms_service.dart';

export 'srs/email_sms_service.dart';
export 'srs/web_sms_service.dart';
export 'srs/interfaces.dart';

/// Main class to initialize and use SMS over Wi-Fi services
class SmsOverWifi {
  static const String version = '1.0.0';

  /// Initialize the package with configuration
  static Future<void> initialize({String? email, String? password}) async {
    if (email != null && password != null) {
      await EmailSmsService.initialize(email: email, password: password);
    }
  }
}
