import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/maintenance_quote.dart';
import 'package:motorz/core/domain/model/ownership.dart';

/// Synthèse financière (TCO) calculée localement, depuis ma date d'acquisition.
class TcoSummary {
  final double? purchasePrice;
  final DateTime? acquiredDate;
  final int? acquiredOdometer;
  final double fuelCost;
  final double maintenanceCost;
  final double otherCost; // assurance + postes libres
  final double tco;
  final int? kmSinceAcquisition;
  final double? costPerKm;
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

abstract final class FinanceService {
  /// Ma période de possession (la ligne courante).
  static Ownership? myOwnership(List<Ownership> ownerships) {
    for (final o in ownerships) {
      if (o.isCurrent) return o;
    }
    return null;
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
    final otherCost = costs.where((e) => since(e.date)).fold<double>(0, (s, e) => s + (e.amount ?? 0));
    final tco = (purchasePrice ?? 0) + fuelCost + maintenanceCost + otherCost;

    final kmSince = (currentOdometer != null && acquiredOdometer != null)
        ? currentOdometer - acquiredOdometer
        : null;
    final costPerKm = (kmSince != null && kmSince > 0) ? tco / kmSince : null;

    double? monthlyCost;
    if (acquiredDate != null) {
      final months = ref.difference(acquiredDate).inDays / 30.4375;
      if (months >= 0.5) monthlyCost = tco / months;
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
