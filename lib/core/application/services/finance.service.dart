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
  final double garageEstimate; // estimatif « tout en garage »
  final double diySavings; // économies DIY

  const TcoSummary({
    required this.fuelCost,
    required this.maintenanceCost,
    required this.otherCost,
    required this.tco,
    required this.garageEstimate,
    required this.diySavings,
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

    // Estimatif « tout en garage » : devis retenu (si compté) sinon coût réel.
    final selectedByOp = <String, MaintenanceQuote>{};
    for (final q in quotes) {
      if (q.isSelected && q.amount != null) selectedByOp[q.operationId.value] = q;
    }
    double garageEstimate = 0;
    double realTotal = 0;
    for (final e in opsList) {
      final real = opCost(e);
      realTotal += real;
      final q = selectedByOp[e.id.value];
      garageEstimate += (q != null && e.countQuoteInEstimate) ? q.amount! : real;
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
      diySavings: garageEstimate - realTotal,
    );
  }
}
