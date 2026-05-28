import 'package:motorz/core/application/services/due_status.service.dart';
import 'package:motorz/core/application/services/finance.service.dart';
import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/application/services/vehicle_stats.service.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/maintenance_catalog_item.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/core/domain/model/maintenance_quote.dart';
import 'package:motorz/core/domain/model/media_item.dart';
import 'package:motorz/core/domain/model/ownership.dart';
import 'package:motorz/core/domain/model/target_pressure.dart';
import 'package:motorz/core/domain/model/tire_pressure_entry.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vehicle_data_providers.g.dart';

/// Plan (échéance) enrichi de son échéance calculée et de sa dernière réalisation.
typedef DuePlan = ({Plan plan, DueInfo due, LastDone? lastDone});

/// Tous les véhicules accessibles (mes véhicules + partagés), depuis le local.
@riverpod
Future<List<Vehicle>> vehicles(Ref ref) async {
  ref.watch(storeChangesProvider);
  final list = await ref.watch(vehicleRepositoryProvider).listAll();
  list.sort((a, b) => a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()));
  return list;
}

@riverpod
Future<Vehicle?> vehicleById(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  return ref.watch(vehicleRepositoryProvider).getById(vehicleId);
}

@riverpod
Future<List<FuelEntry>> fuelEntries(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final list = await ref.watch(fuelRepositoryProvider).listForVehicle(vehicleId);
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

/// Opérations d'entretien réalisées du véhicule (plus récentes d'abord).
@riverpod
Future<List<Operation>> operations(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final list = await ref.watch(operationRepositoryProvider).listForVehicle(vehicleId);
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

/// Lignes d'une opération (un poste fait par ligne).
@riverpod
Future<List<OperationLine>> operationLines(Ref ref, String operationId) async {
  ref.watch(storeChangesProvider);
  final all = await ref.watch(operationLineRepositoryProvider).listAll();
  return all.where((l) => l.operationId.value == operationId).toList();
}

/// Toutes les lignes d'opérations du véhicule (pour la dérivation des échéances).
@riverpod
Future<List<OperationLine>> linesForVehicle(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final ops = await ref.watch(operationsProvider(vehicleId).future);
  final opIds = ops.map((o) => o.id.value).toSet();
  final all = await ref.watch(operationLineRepositoryProvider).listAll();
  return all.where((l) => opIds.contains(l.operationId.value)).toList();
}

/// Plans (échéances à prévoir) du véhicule.
@riverpod
Future<List<Plan>> plans(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  return ref.watch(planRepositoryProvider).listForVehicle(vehicleId);
}

/// Catalogue de postes de l'utilisateur (trié par nom).
@riverpod
Future<List<CatalogItem>> catalogItems(Ref ref) async {
  ref.watch(storeChangesProvider);
  final list = await ref.watch(catalogItemRepositoryProvider).listAll();
  list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return list;
}

@riverpod
Future<List<TirePressureEntry>> tirePressures(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final list = await ref.watch(tirePressureRepositoryProvider).listForVehicle(vehicleId);
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

@riverpod
Future<List<TargetPressure>> targetPressures(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final list = await ref.watch(targetPressureRepositoryProvider).listForVehicle(vehicleId);
  list.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return list;
}

@riverpod
Future<List<Ownership>> ownerships(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final list = await ref.watch(ownershipRepositoryProvider).listForVehicle(vehicleId);
  // Plus ancien → plus récent (par km d'acquisition puis date).
  list.sort((a, b) => (a.acquiredOdometer ?? 0).compareTo(b.acquiredOdometer ?? 0));
  return list;
}

@riverpod
Future<List<CostEntry>> costEntries(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final list = await ref.watch(costEntryRepositoryProvider).listForVehicle(vehicleId);
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

/// Devis du véhicule (filtrés via les opérations d'entretien du véhicule).
@riverpod
Future<List<MaintenanceQuote>> quotesForVehicle(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final ops = await ref.watch(operationsProvider(vehicleId).future);
  final opIds = ops.map((e) => e.id.value).toSet();
  final all = await ref.watch(maintenanceQuoteRepositoryProvider).listAll();
  return all.where((q) => opIds.contains(q.operationId.value)).toList();
}

@riverpod
Future<List<MaintenanceQuote>> quotesForOperation(Ref ref, String operationId) async {
  ref.watch(storeChangesProvider);
  final all = await ref.watch(maintenanceQuoteRepositoryProvider).listAll();
  return all.where((q) => q.operationId.value == operationId).toList();
}

/// Documents (photos/PDF) rattachés à une cible (véhicule, plein, opération…).
@riverpod
Future<List<MediaItem>> mediaForOwner(Ref ref, String ownerId) async {
  ref.watch(storeChangesProvider);
  final all = await ref.watch(mediaRepositoryProvider).listAll();
  return all.where((m) => m.ownerId.value == ownerId).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
}

/// Synthèse TCO (mon achat + carburant + entretien + autres frais depuis mon achat).
@riverpod
Future<TcoSummary> financeSummary(Ref ref, String vehicleId) async {
  final ownerships = await ref.watch(ownershipsProvider(vehicleId).future);
  final fuel = await ref.watch(fuelEntriesProvider(vehicleId).future);
  final ops = await ref.watch(operationsProvider(vehicleId).future);
  final lines = await ref.watch(linesForVehicleProvider(vehicleId).future);
  final costs = await ref.watch(costEntriesProvider(vehicleId).future);
  final quotes = await ref.watch(quotesForVehicleProvider(vehicleId).future);
  final odo = await ref.watch(currentOdometerProvider(vehicleId).future);
  return FinanceService.compute(
    ownerships: ownerships,
    fuel: fuel,
    operations: ops,
    lines: lines,
    costs: costs,
    quotes: quotes,
    currentOdometer: odo,
  );
}

/// Km courant dérivé localement (MAX odometer toutes saisies).
@riverpod
Future<int?> currentOdometer(Ref ref, String vehicleId) async {
  final fuel = await ref.watch(fuelEntriesProvider(vehicleId).future);
  final ops = await ref.watch(operationsProvider(vehicleId).future);
  final tires = await ref.watch(tirePressuresProvider(vehicleId).future);
  return VehicleStatsService.currentOdometer(fuel: fuel, operations: ops, tires: tires);
}

@riverpod
Future<double?> averageConsumption(Ref ref, String vehicleId) async {
  final fuel = await ref.watch(fuelEntriesProvider(vehicleId).future);
  return VehicleStatsService.averageConsumption(fuel);
}

/// Échéances triées par urgence (en retard, puis bientôt, puis à venir).
/// Projection pure : plans + historique (dernière réalisation dérivée).
@riverpod
Future<List<DuePlan>> duePlans(Ref ref, String vehicleId) async {
  final plans = await ref.watch(plansProvider(vehicleId).future);
  final ops = await ref.watch(operationsProvider(vehicleId).future);
  final lines = await ref.watch(linesForVehicleProvider(vehicleId).future);
  final odo = await ref.watch(currentOdometerProvider(vehicleId).future);
  final lastDones = MaintenanceDerivationService.lastDoneAll(plans, ops, lines);
  final result = [
    for (final pl in lastDones)
      (
        plan: pl.plan,
        lastDone: pl.lastDone,
        due: DueStatusService.compute(pl.plan, lastDone: pl.lastDone, currentOdometer: odo),
      ),
  ];
  int rank(DueStatus s) => switch (s) {
    DueStatus.overdue => 0,
    DueStatus.dueSoon => 1,
    DueStatus.upcoming => 2,
  };
  result.sort((a, b) => rank(a.due.status).compareTo(rank(b.due.status)));
  return result;
}
