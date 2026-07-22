import 'package:motorz/core/domain/model/uuid_value.dart';

/// Devis comparatif rattaché à une opération d'entretien (§5.5) : ce qu'un
/// **garage** aurait facturé. Jamais compté comme dépense réelle — il alimente
/// l'estimatif « tout en garage » et, quand l'opération est faite soi-même, les
/// économies DIY.
///
/// Une opération peut en porter plusieurs (un par garage consulté) ; un seul
/// fait référence — cf. [retainedIn].
class MaintenanceQuote {
  final UuidValue id;
  final UuidValue operationId;

  /// Garage qui a chiffré. Même notion que `Operation.provider`.
  final String? provider;
  final double? amount;

  /// Devis de référence de l'opération. Voir [retainedIn] : la lecture ne s'y
  /// fie jamais seule, un lot peut n'en marquer aucun (données antérieures) ou
  /// deux (écritures concurrentes sur deux appareils).
  final bool isSelected;
  final String? notes;

  /// Date de saisie — porte l'**ordre** des devis d'une opération, donc « le
  /// premier saisi », qui fait référence par défaut.
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  MaintenanceQuote({
    required this.id,
    required this.operationId,
    required this.createdAt,
    required this.updatedAt,
    this.provider,
    this.amount,
    this.isSelected = false,
    this.notes,
    this.deletedAt,
  });

  /// Devis vivants, dans l'ordre de saisie (départage par id pour rester stable
  /// quand deux devis partagent la même date).
  static List<MaintenanceQuote> ordered(Iterable<MaintenanceQuote> quotes) {
    final live = quotes.where((q) => q.deletedAt == null).toList()
      ..sort((a, b) {
        final byDate = a.createdAt.compareTo(b.createdAt);
        return byDate != 0 ? byDate : a.id.value.compareTo(b.id.value);
      });
    return live;
  }

  /// Devis de référence d'une opération : celui marqué [isSelected], **sinon le
  /// premier saisi**. Le repli évite qu'un lot sans devis retenu (import,
  /// données antérieures au marquage) n'alimente plus rien silencieusement.
  static MaintenanceQuote? retainedIn(Iterable<MaintenanceQuote> quotes) {
    final live = ordered(quotes);
    if (live.isEmpty) return null;
    return live.firstWhere((q) => q.isSelected, orElse: () => live.first);
  }

  MaintenanceQuote copyWith({
    String? provider,
    double? amount,
    bool? isSelected,
    String? notes,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return MaintenanceQuote(
      id: id,
      operationId: operationId,
      provider: provider ?? this.provider,
      amount: amount ?? this.amount,
      isSelected: isSelected ?? this.isSelected,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceQuote && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
