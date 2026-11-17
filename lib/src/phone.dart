import 'package:phone_numbers_parser/phone_numbers_parser.dart' as pnp;

/// Phone-number helpers for SMS-over-Wi-Fi gateways and HTTP APIs.
class PhoneNumber {
  PhoneNumber._();

  /// Keep digits only.
  static String digitsOnly(String phoneNumber) {
    return phoneNumber.replaceAll(RegExp(r'\D'), '');
  }

  static pnp.IsoCode? _iso(String? countryCode) {
    if (countryCode == null || countryCode.trim().isEmpty) return null;
    final key = countryCode.trim().toUpperCase();
    try {
      return pnp.IsoCode.values.byName(key);
    } catch (_) {
      return null;
    }
  }

  static pnp.PhoneNumber? _parse(String phoneNumber, {String? countryCode}) {
    final iso = _iso(countryCode) ?? pnp.IsoCode.US;
    try {
      return pnp.PhoneNumber.parse(
        phoneNumber,
        callerCountry: iso,
        destinationCountry: iso,
      );
    } catch (_) {
      try {
        return pnp.PhoneNumber.parse(phoneNumber);
      } catch (_) {
        return null;
      }
    }
  }

  /// Normalize for US/CA email-to-SMS gateways: 10-digit national number when
  /// possible; otherwise digits best-effort.
  static String forGateway(String phoneNumber, {String? countryCode}) {
    final parsed = _parse(phoneNumber, countryCode: countryCode);
    if (parsed != null) {
      if (parsed.isoCode == pnp.IsoCode.US ||
          parsed.isoCode == pnp.IsoCode.CA) {
        return parsed.nsn;
      }
      return digitsOnly(parsed.international);
    }

    var digits = digitsOnly(phoneNumber);
    final cc = (countryCode ?? 'US').toUpperCase();
    if ((cc == 'US' || cc == 'CA') &&
        digits.length == 11 &&
        digits.startsWith('1')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// E.164 form (`+263782926585`). Falls back to `+` + digits.
  static String toE164(String phoneNumber, {String? countryCode}) {
    final parsed = _parse(phoneNumber, countryCode: countryCode);
    if (parsed != null) {
      return parsed.international;
    }
    final digits = digitsOnly(phoneNumber);
    return digits.startsWith('+') ? digits : '+$digits';
  }

  /// Length / parse plausibility check.
  static bool isPlausible(String phoneOrDigits, {String? countryCode}) {
    final parsed = _parse(phoneOrDigits, countryCode: countryCode);
    if (parsed != null) {
      return parsed.isValidLength() ||
          (parsed.nsn.length >= 7 && parsed.nsn.length <= 15);
    }
    final digits = digitsOnly(phoneOrDigits);
    return digits.length >= 7 && digits.length <= 15;
  }
}
