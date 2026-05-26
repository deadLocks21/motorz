import 'package:uuid/uuid.dart';

/// Value Object pour un UUID v4. Garantit une valeur toujours valide.
/// Les IDs sont générés côté client (offline-first) → pas d'attente serveur.
class UuidValue {
  final String value;

  const UuidValue._(this.value);

  factory UuidValue.generate() => UuidValue._(const Uuid().v4());

  factory UuidValue.parse(String value) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuidRegex.hasMatch(value)) {
      throw ArgumentError('Invalid UUID format: $value');
    }
    return UuidValue._(value);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UuidValue && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
