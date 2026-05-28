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
  final String? provider;
  final String? note;
  final bool countQuoteInEstimate;
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
    this.countQuoteInEstimate = true,
    this.deletedAt,
  });

  Operation copyWith({
    DateTime? date,
    int? odometer,
    String? title,
    String? provider,
    String? note,
    bool? countQuoteInEstimate,
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
      countQuoteInEstimate: countQuoteInEstimate ?? this.countQuoteInEstimate,
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
