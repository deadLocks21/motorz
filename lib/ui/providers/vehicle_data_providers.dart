import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:motorz/core/application/services/due_status.service.dart';
import 'package:motorz/core/application/services/finance.service.dart';
import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/application/services/vehicle_stats.service.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
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
  // Pleins sans date (km seul) en tête pour penser à les compléter ; le reste
  // par date décroissante.
  list.sort((a, b) {
    if (a.date == null) return b.date == null ? 0 : -1;
    if (b.date == null) return 1;
    return b.date!.compareTo(a.date!);
  });
  return list;
}

/// Stations déjà saisies, tous véhicules confondus — pour l'autocomplétion du
/// champ « Station » d'un plein (on fait le plein aux mêmes endroits quel que
/// soit le véhicule). Voir [rankStations] pour l'ordre.
@riverpod
Future<List<String>> knownStations(Ref ref) async {
  ref.watch(storeChangesProvider);
  return rankStations(await ref.watch(fuelRepositoryProvider).listAll());
}

/// Ordonne pour l'autocomplétion **toutes** les stations connues de [entries]
/// (pas seulement les récentes) par nombre d'occurrences sur les **10 derniers
/// pleins** (les stations habituelles du moment remontent), puis par fréquence
/// globale et enfin alphabétiquement pour départager. Dédoublonnage sans tenir
/// compte de la casse (« Total » / « total »), l'orthographe affichée étant la
/// première vue.
@visibleForTesting
List<String> rankStations(List<FuelEntry> entries) {
  // 10 derniers pleins par date décroissante ; ceux sans date (km seul) en
  // dernier car non situables dans le temps.
  final byRecency = [...entries]..sort((a, b) {
      final da = a.date, db = b.date;
      if (da == null) return db == null ? 0 : 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
  final recent = <String, int>{}; // occurrences sur les 10 derniers pleins
  for (final e in byRecency.take(10)) {
    final key = e.station?.trim().toLowerCase();
    if (key == null || key.isEmpty) continue;
    recent.update(key, (n) => n + 1, ifAbsent: () => 1);
  }

  final total = <String, int>{}; // fréquence globale (départage)
  final labels = <String, String>{}; // clé normalisée → orthographe affichée
  for (final e in entries) {
    final raw = e.station?.trim();
    if (raw == null || raw.isEmpty) continue;
    final key = raw.toLowerCase();
    total.update(key, (n) => n + 1, ifAbsent: () => 1);
    labels.putIfAbsent(key, () => raw);
  }

  final keys = labels.keys.toList()
    ..sort((a, b) {
      final byRecent = (recent[b] ?? 0).compareTo(recent[a] ?? 0);
      if (byRecent != 0) return byRecent;
      final byTotal = total[b]!.compareTo(total[a]!);
      return byTotal != 0 ? byTotal : a.compareTo(b);
    });
  return [for (final k in keys) labels[k]!];
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
  final result = <DuePlan>[];
  for (final pl in lastDones) {
    // Tâche ponctuelle (sans intervalle) déjà faite → masquée de À prévoir.
    if (!pl.plan.isRecurring &&
        MaintenanceDerivationService.isOneShotDone(pl.plan, ops, lines)) {
      continue;
    }
    result.add((
      plan: pl.plan,
      lastDone: pl.lastDone,
      due: DueStatusService.compute(pl.plan, lastDone: pl.lastDone, currentOdometer: odo),
    ));
  }
  int rank(DueStatus s) => switch (s) {
    DueStatus.overdue => 0,
    DueStatus.dueSoon => 1,
    DueStatus.upcoming => 2,
  };
  result.sort((a, b) => rank(a.due.status).compareTo(rank(b.due.status)));
  return result;
}
