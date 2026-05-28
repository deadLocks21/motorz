import 'package:motorz/core/domain/model/uuid_value.dart';

/// Poste type du catalogue d'entretien (bibliothèque **par utilisateur**, §5.6).
/// Sert à la fois de libellé et de clé de regroupement (coût par catégorie).
/// Les intervalles par défaut amorcent les plans récurrents qui le référencent.
class CatalogItem {
  final UuidValue id;
  final UuidValue userId;
  final String name;
  final int? defaultIntervalKm;
  final int? defaultIntervalMonths;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  CatalogItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.updatedAt,
    this.defaultIntervalKm,
    this.defaultIntervalMonths,
    this.deletedAt,
  }) : assert(name.trim().isNotEmpty, 'name cannot be empty');

  CatalogItem copyWith({
    String? name,
    int? defaultIntervalKm,
    int? defaultIntervalMonths,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return CatalogItem(
      id: id,
      userId: userId,
      name: name ?? this.name,
      defaultIntervalKm: defaultIntervalKm ?? this.defaultIntervalKm,
      defaultIntervalMonths: defaultIntervalMonths ?? this.defaultIntervalMonths,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CatalogItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
