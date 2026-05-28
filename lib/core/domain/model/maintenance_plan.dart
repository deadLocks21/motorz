import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Échéance à prévoir (§5.6). Deux natures, implicites :
/// - **récurrente** : rattachée à un poste de catalogue avec au moins un
///   intervalle (km/mois) ; sa prochaine échéance est dérivée de l'historique ;
/// - **à venir / ponctuelle** : cible `dueDate`/`dueOdometer` sans intervalle
///   (CT d'une occasion, distribution jamais faite, réparation one-shot).
///
/// La **dernière réalisation n'est PAS stockée** — elle est dérivée des
/// opérations (cf. `MaintenanceDerivationService`).
class Plan {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue? catalogItemId;
  final String? title;
  final TaskPriority? priority;
  final double? estimatedCost;
  final int? intervalKm;
  final int? intervalMonths;
  final String? dueDate; // YYYY-MM-DD (amorce / one-shot)
  final int? dueOdometer;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Plan({
    required this.id,
    required this.vehicleId,
    required this.updatedAt,
    this.catalogItemId,
    this.title,
    this.priority,
    this.estimatedCost,
    this.intervalKm,
    this.intervalMonths,
    this.dueDate,
    this.dueOdometer,
    this.deletedAt,
  });

  /// Récurrent = rattaché à un poste de catalogue avec au moins un intervalle.
  bool get isRecurring =>
      catalogItemId != null && (intervalKm != null || intervalMonths != null);

  Plan copyWith({
    UuidValue? catalogItemId,
    String? title,
    TaskPriority? priority,
    double? estimatedCost,
    int? intervalKm,
    int? intervalMonths,
    String? dueDate,
    int? dueOdometer,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return Plan(
      id: id,
      vehicleId: vehicleId,
      catalogItemId: catalogItemId ?? this.catalogItemId,
      title: title ?? this.title,
      priority: priority ?? this.priority,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      intervalKm: intervalKm ?? this.intervalKm,
      intervalMonths: intervalMonths ?? this.intervalMonths,
      dueDate: dueDate ?? this.dueDate,
      dueOdometer: dueOdometer ?? this.dueOdometer,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Plan && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
