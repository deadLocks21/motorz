import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/maintenance_quote.dart';
import 'package:motorz/core/domain/model/ownership.dart';

/// Synthèse financière calculée localement, depuis ma date d'acquisition.
///
/// Deux niveaux de lecture, volontairement séparés (§5.2) :
/// - le **coût d'usage** ([usageCost]) — ce que le véhicule me coûte à rouler ;
///   c'est lui, et lui seul, qui porte [monthlyCost] et [costPerKm] ;
/// - le **coût total de possession** ([tco]) — le coût d'usage plus le prix
///   d'achat.
///
/// Le prix d'achat est un capital immobilisé, pas une dépense courante :
/// l'inclure dans le €/mois écrase tout le reste les premières années et rend
/// les deux ratios illisibles.
class TcoSummary {
  final double? purchasePrice;
  final DateTime? acquiredDate;
  final int? acquiredOdometer;
  final double fuelCost;
  final double maintenanceCost;
  final double otherCost; // assurance + postes libres (récurrents étalés)

  /// Carburant + entretien + assurance & frais — hors prix d'achat.
  final double usageCost;

  /// Charge fixe mensuelle **courante** : somme des frais récurrents en cours
  /// aujourd'hui, ramenés au mois. Zéro s'il n'y en a aucun.
  final double recurringMonthly;

  /// Coût d'usage + prix d'achat.
  final double tco;
  final int? kmSinceAcquisition;

  /// Coût d'usage au kilomètre (hors prix d'achat).
  final double? costPerKm;

  /// Coût d'usage moyen par mois de possession (hors prix d'achat).
  final double? monthlyCost;
  /// Estimatif « tout en garage » : ce que l'entretien aurait coûté si tout
  /// avait été confié à un garage.
  final double garageEstimate;

  /// Économies DIY : sur les seules opérations **faites moi-même**, l'écart
  /// entre le devis retenu et ce que j'ai réellement dépensé.
  final double diySavings;

  /// Nombre d'opérations portant un devis chiffré. À zéro, l'estimatif ne dit
  /// rien de plus que le coût réel — l'UI masque le bloc.
  final int quotedOperationCount;

  const TcoSummary({
    required this.fuelCost,
    required this.maintenanceCost,
    required this.otherCost,
    required this.usageCost,
    required this.recurringMonthly,
    required this.tco,
    required this.garageEstimate,
    required this.diySavings,
    required this.quotedOperationCount,
    this.purchasePrice,
    this.acquiredDate,
    this.acquiredOdometer,
    this.kmSinceAcquisition,
    this.costPerKm,
    this.monthlyCost,
  });
}

/// Durée moyenne d'un mois, en jours — le TCO raisonne en mois glissants, pas
/// en mois calendaires.
const _daysPerMonth = 30.4375;

abstract final class FinanceService {
  /// Ma période de possession (la ligne courante).
  static Ownership? myOwnership(List<Ownership> ownerships) {
    for (final o in ownerships) {
      if (o.isCurrent) return o;
    }
    return null;
  }

  /// Ce qu'une charge récurrente m'a coûté à ce jour : son équivalent mensuel
  /// multiplié par les mois réellement écoulés.
  ///
  /// La fenêtre est bornée des deux côtés — elle démarre au plus tard entre le
  /// début de la charge et mon acquisition (une assurance souscrite par
  /// l'ancien propriétaire ne m'est pas imputable), et s'arrête au plus tôt
  /// entre sa fin et aujourd'hui (on compte le couru, jamais le prévisionnel).
  /// Une fenêtre vide ou inversée — fin avant début, début dans le futur — vaut
  /// zéro : c'est ici, et pas dans la validation d'API, que les deux chemins
  /// d'écriture (REST et synchro) convergent.
  static double accruedTo(CostEntry e, {DateTime? since, required DateTime ref}) {
    final monthly = e.monthlyAmount;
    if (monthly == null) return 0;
    final start = (since != null && since.isAfter(e.date)) ? since : e.date;
    final end = (e.endDate != null && e.endDate!.isBefore(ref)) ? e.endDate! : ref;
    final days = end.difference(start).inDays;
    return days <= 0 ? 0 : monthly * (days / _daysPerMonth);
  }

  static TcoSummary compute({
    required List<Ownership> ownerships,
    required List<FuelEntry> fuel,
    required List<Operation> operations,
    required List<OperationLine> lines,
    required List<CostEntry> costs,
    List<MaintenanceQuote> quotes = const [],
    int? currentOdometer,
    DateTime? now,
  }) {
    final ref = now ?? DateTime.now();
    final mine = myOwnership(ownerships);
    final acquiredDate = mine?.acquiredDate != null ? DateTime.tryParse(mine!.acquiredDate!) : null;
    final purchasePrice = mine?.purchasePrice;
    final acquiredOdometer = mine?.acquiredOdometer;

    // Seules les dépenses datées ≥ ma date d'acquisition comptent (§5.2).
    bool since(DateTime d) => acquiredDate == null || !d.isBefore(acquiredDate);

    // Coût réel d'une opération = somme de ses lignes.
    final linesByOp = <String, List<OperationLine>>{};
    for (final l in lines) {
      (linesByOp[l.operationId.value] ??= []).add(l);
    }
    double opCost(Operation o) =>
        MaintenanceDerivationService.operationCost(linesByOp[o.id.value] ?? const []) ?? 0;

    final fuelCost = fuel
        .where((e) => e.date == null || since(e.date!))
        .fold<double>(0, (s, e) => s + (e.totalCost ?? 0));
    final opsList = operations.where((e) => since(e.date)).toList();
    final maintenanceCost = opsList.fold<double>(0, (s, e) => s + opCost(e));

    // Un frais ponctuel compte pour son montant s'il est daté après mon achat ;
    // un frais récurrent compte pour ce qui a couru pendant ma possession —
    // d'où le filtre par date sur les seuls ponctuels, `accruedTo` bornant
    // déjà la fenêtre des récurrents.
    var otherCost = 0.0;
    var recurringMonthly = 0.0;
    for (final c in costs) {
      if (c.recurrence.isRecurring) {
        otherCost += accruedTo(c, since: acquiredDate, ref: ref);
        if (c.isActiveAt(ref)) recurringMonthly += c.monthlyAmount ?? 0;
      } else if (since(c.date)) {
        otherCost += c.amount ?? 0;
      }
    }

    final usageCost = fuelCost + maintenanceCost + otherCost;
    final tco = (purchasePrice ?? 0) + usageCost;

    final kmSince = (currentOdometer != null && acquiredOdometer != null)
        ? currentOdometer - acquiredOdometer
        : null;
    // Ratios assis sur le coût d'usage : le prix d'achat n'est pas une dépense
    // au kilomètre ni au mois (cf. [TcoSummary]).
    final costPerKm = (kmSince != null && kmSince > 0) ? usageCost / kmSince : null;

    double? monthlyCost;
    if (acquiredDate != null) {
      final months = ref.difference(acquiredDate).inDays / _daysPerMonth;
      if (months >= 0.5) monthlyCost = usageCost / months;
    }

    // Un devis suffit à faire foi : saisi = compté. Le devis de référence d'une
    // opération est celui retenu, à défaut le premier saisi (cf. [retainedIn]).
    final quotesByOp = <String, List<MaintenanceQuote>>{};
    for (final q in quotes) {
      (quotesByOp[q.operationId.value] ??= []).add(q);
    }
    double? quotedAmount(Operation o) =>
        MaintenanceQuote.retainedIn(quotesByOp[o.id.value] ?? const [])?.amount;

    // Estimatif « tout en garage » : devis de référence quand il y en a un,
    // sinon le coût réel (une opération déjà faite en garage est à son prix).
    double garageEstimate = 0;
    double diySavings = 0;
    var quotedOperationCount = 0;
    for (final e in opsList) {
      final real = opCost(e);
      final quoted = quotedAmount(e);
      garageEstimate += quoted ?? real;
      if (quoted == null) continue;
      quotedOperationCount++;
      // Ce que j'ai évité de payer n'a de sens que si c'est moi qui ai mis les
      // mains dedans : sur une opération confiée à un garage, l'écart avec un
      // devis concurrent n'est pas une économie réalisée.
      if (e.isDiy) diySavings += quoted - real;
    }

    return TcoSummary(
      purchasePrice: purchasePrice,
      acquiredDate: acquiredDate,
      acquiredOdometer: acquiredOdometer,
      fuelCost: fuelCost,
      maintenanceCost: maintenanceCost,
      otherCost: otherCost,
      usageCost: usageCost,
      recurringMonthly: recurringMonthly,
      tco: tco,
      kmSinceAcquisition: kmSince,
      costPerKm: costPerKm,
      monthlyCost: monthlyCost,
      garageEstimate: garageEstimate,
      diySavings: diySavings,
      quotedOperationCount: quotedOperationCount,
    );
  }
}
