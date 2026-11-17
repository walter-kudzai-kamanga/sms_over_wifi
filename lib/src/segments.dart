/// Estimates how many SMS segments a body will consume.
///
/// Uses GSM-7 (160 / 153) vs UCS-2 (70 / 67) rules. This is advisory for
/// carriers and APIs; exact billing may still differ by provider.
class SmsSegments {
  SmsSegments._();

  /// GSM-7 default alphabet (basic set). Extension chars count as two septets
  /// in real networks; this helper treats them as GSM-compatible for encoding
  /// selection only.
  static const String _gsmBasic =
      '@£\$¥èéùìòÇ\nØø\rÅæΔ_ΦΓΛΩΠΨΣΘΞ ÆæßÉ'
      ' !"#¤%&\'()*+,-./0123456789:;<=>?'
      '¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§'
      '¿abcdefghijklmnopqrstuvwxyzäöñüà';

  static const String _gsmExtended = r'^{}\[~]|€';

  static bool isGsmCompatible(String message) {
    for (final codeUnit in message.codeUnits) {
      final ch = String.fromCharCode(codeUnit);
      if (!_gsmBasic.contains(ch) && !_gsmExtended.contains(ch)) {
        return false;
      }
    }
    return true;
  }

  /// Number of SMS segments for [message]. Empty → 0.
  static int count(String message) {
    if (message.isEmpty) return 0;
    if (isGsmCompatible(message)) {
      if (message.length <= 160) return 1;
      return (message.length / 153).ceil();
    }
    if (message.length <= 70) return 1;
    return (message.length / 67).ceil();
  }

  static bool exceedsSingleSegment(String message) => count(message) > 1;
}
