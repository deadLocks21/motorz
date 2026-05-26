/// Value Object : mobile français normalisé en E.164 (`+33[67]…`).
class PhoneNumber {
  /// Forme E.164, ex. `+33612345678`.
  final String e164;

  const PhoneNumber._(this.e164);

  static final _e164 = RegExp(r'^\+33[67]\d{8}$');

  /// Normalise une saisie libre (`06 12 …`, `+33 6 …`) puis valide.
  factory PhoneNumber.parse(String raw) {
    var s = raw.replaceAll(RegExp(r'[\s.\-()]'), '');
    if (s.startsWith('0') && s.length == 10) {
      s = '+33${s.substring(1)}';
    } else if (s.startsWith('33') && s.length == 11) {
      s = '+$s';
    }
    if (!_e164.hasMatch(s)) {
      throw const FormatException('Numéro de mobile français invalide');
    }
    return PhoneNumber._(s);
  }

  static bool isValid(String raw) {
    try {
      PhoneNumber.parse(raw);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PhoneNumber && runtimeType == other.runtimeType && e164 == other.e164;

  @override
  int get hashCode => e164.hashCode;

  @override
  String toString() => e164;
}
