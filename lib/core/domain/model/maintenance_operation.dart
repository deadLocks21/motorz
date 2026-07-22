import 'package:motorz/core/domain/model/uuid_value.dart';

/// Opération d'entretien réalisée = **une visite** (date + km), composée de
/// lignes (cf. `OperationLine`). Le coût total est la **somme des lignes** —
/// jamais stocké ici. Le **titre est optionnel** : dérivé des lignes s'il est nul.
class Operation {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue? createdByUserId;
  final DateTime date;
  final int odometer;
  final String? title;

  /// Garage. **Nul quand [isDiy]** : « moi-même » ne se saisit pas en texte libre.
  final String? provider;
  final String? note;

  /// Opération faite par moi-même. Seules celles-ci alimentent les économies
  /// DIY (ce que j'ai évité de payer à un garage, cf. `FinanceService`).
  final bool isDiy;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Operation({
    required this.id,
    required this.vehicleId,
    required this.date,
    required this.odometer,
    required this.updatedAt,
    this.createdByUserId,
    this.title,
    this.provider,
    this.note,
    this.isDiy = false,
    this.deletedAt,
  });

  Operation copyWith({
    DateTime? date,
    int? odometer,
    String? title,
    String? provider,
    String? note,
    bool? isDiy,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Operation(
      id: id,
      vehicleId: vehicleId,
      createdByUserId: createdByUserId,
      date: date ?? this.date,
      odometer: odometer ?? this.odometer,
      title: title ?? this.title,
      provider: provider ?? this.provider,
      note: note ?? this.note,
      isDiy: isDiy ?? this.isDiy,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Operation && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
