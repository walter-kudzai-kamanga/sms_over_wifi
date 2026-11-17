/// Known email-to-SMS gateway domains by carrier key.
///
/// **Best-effort only.** Carriers retire or change gateways without notice;
/// delivery is not guaranteed. Prefer Twilio/HTTP APIs for production.
class CarrierGateways {
  CarrierGateways._();

  static const Map<String, String> all = {
    // USA
    'att': 'txt.att.net',
    'verizon': 'vtext.com',
    'tmobile': 'tmomail.net',
    'sprint': 'messaging.sprintpcs.com',
    'boost': 'smsmyboostmobile.com',
    'cricket': 'sms.cricketwireless.net',
    'metro': 'mymetropcs.com',
    'uscellular': 'email.uscc.net',
    'virgin': 'vmobl.com',
    'googlefi': 'msg.fi.google.com',

    // Canada
    'rogers': 'pcs.rogers.com',
    'bell': 'txt.bell.ca',
    'telus': 'msg.telus.com',
    'fido': 'fido.ca',
    'virgincanada': 'vmobile.ca',

    // UK
    'vodafone': 'vodafone.net',
    'o2': 'o2.co.uk',
    'ee': 'mms.ee.co.uk',
    'three': 'three.co.uk',
  };

  /// Extra aliases normalized to keys in [all].
  static const Map<String, String> aliases = {
    'atandt': 'att',
    'attwireless': 'att',
    'vzw': 'verizon',
    'verizonwireless': 'verizon',
    'tmobileusa': 'tmobile',
    'metropcs': 'metro',
    'googlefiwireless': 'googlefi',
    'fi': 'googlefi',
    'usc': 'uscellular',
    'virginmobile': 'virgin',
    'virginmobilecanada': 'virgincanada',
    'bellcanada': 'bell',
    'telusmobility': 'telus',
    'o2uk': 'o2',
    'eeuk': 'ee',
    'threemuk': 'three',
    'vodafoneuk': 'vodafone',
  };

  static String _normalize(String carrier) {
    return carrier.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  /// Canonical carrier key, or null if unknown.
  static String? resolveKey(String carrier) {
    final key = _normalize(carrier);
    if (all.containsKey(key)) return key;
    final aliased = aliases[key];
    if (aliased != null && all.containsKey(aliased)) return aliased;
    return null;
  }

  /// Returns the gateway domain for [carrier], or null if unknown.
  static String? domainFor(String carrier) {
    final key = resolveKey(carrier);
    if (key == null) return null;
    return all[key];
  }

  /// Builds `number@gateway` for a carrier, or null if the carrier is unknown.
  static String? addressFor({
    required String phoneDigits,
    required String carrier,
  }) {
    final domain = domainFor(carrier);
    if (domain == null || phoneDigits.isEmpty) return null;
    return '$phoneDigits@$domain';
  }

  static List<String> get supportedCarriers =>
      all.keys.toList(growable: false);
}
