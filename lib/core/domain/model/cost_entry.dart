import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Poste de coût libre / assurance — alimente le TCO (§5.2).
///
/// Deux natures, distinguées par [recurrence] :
/// - **ponctuelle** : un paiement daté ([date]), compté tel quel ;
/// - **récurrente** : une charge perpétuelle décrite une fois — [amount] est le
///   montant *par période*, [date] le début, [endDate] la fin (`null` = en
///   cours). Le TCO l'étale au prorata au lieu d'exiger une ligne par échéance.
class CostEntry {
  final UuidValue id;
  final UuidValue vehicleId;
  final UuidValue? createdByUserId;
  final String label;
  final String? category; // ex. 'assurance' | 'autre'
  /// Montant *par période* quand [recurrence] est récurrente, sinon le montant
  /// du paiement.
  final double? amount;
  final CostRecurrence recurrence;
  /// Paiement (ponctuel) ou début de la charge (récurrent).
  final DateTime date;
  /// Récurrent seulement : fin de la charge. `null` = toujours en cours.
  final DateTime? endDate;
  final String? notes;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  CostEntry({
    required this.id,
    required this.vehicleId,
    required this.label,
    required this.date,
    required this.updatedAt,
    this.recurrence = CostRecurrence.ponctuel,
    this.endDate,
    this.createdByUserId,
    this.category,
    this.amount,
    this.notes,
    this.deletedAt,
  }) : assert(label.trim().isNotEmpty, 'label cannot be empty');

  /// Équivalent mensuel d'une charge récurrente (800 €/an → 65,71 €/mois).
  /// `null` sur un frais ponctuel : il ne se ramène pas à un rythme.
  double? get monthlyAmount =>
      (!recurrence.isRecurring || amount == null) ? null : amount! / recurrence.months;

  /// La charge court-elle à la date [ref] ? Sert à sommer le « fixe par mois »
  /// d'aujourd'hui, sans les contrats résiliés ni ceux qui n'ont pas commencé.
  bool isActiveAt(DateTime ref) =>
      recurrence.isRecurring &&
      !date.isAfter(ref) &&
      (endDate == null || !endDate!.isBefore(ref));

  CostEntry copyWith({
    String? label,
    String? category,
    double? amount,
    CostRecurrence? recurrence,
    DateTime? date,
    DateTime? endDate,
    bool clearEndDate = false,
    String? notes,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) => CostEntry(
    id: id,
    vehicleId: vehicleId,
    createdByUserId: createdByUserId,
    label: label ?? this.label,
    category: category ?? this.category,
    amount: amount ?? this.amount,
    recurrence: recurrence ?? this.recurrence,
    date: date ?? this.date,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    notes: notes ?? this.notes,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CostEntry && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
