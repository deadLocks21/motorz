import 'package:motorz/core/application/services/due_status.service.dart';
import 'package:motorz/core/application/services/finance.service.dart';
import 'package:motorz/core/application/services/vehicle_stats.service.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/maintenance_event.dart';
import 'package:motorz/core/domain/model/maintenance_quote.dart';
import 'package:motorz/core/domain/model/maintenance_task.dart';
import 'package:motorz/core/domain/model/media_item.dart';
import 'package:motorz/core/domain/model/ownership.dart';
import 'package:motorz/core/domain/model/target_pressure.dart';
import 'package:motorz/core/domain/model/tire_pressure_entry.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/repository_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'vehicle_data_providers.g.dart';

/// Tâche du backlog enrichie de son échéance calculée.
typedef DueTask = ({MaintenanceTask task, DueInfo due});

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

@riverpod
Future<List<MaintenanceEvent>> maintenanceEvents(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final list = await ref.watch(maintenanceEventRepositoryProvider).listForVehicle(vehicleId);
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

@riverpod
Future<List<MaintenanceTask>> maintenanceTasks(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  return ref.watch(maintenanceTaskRepositoryProvider).listForVehicle(vehicleId);
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
  final events = await ref.watch(maintenanceEventsProvider(vehicleId).future);
  final eventIds = events.map((e) => e.id.value).toSet();
  final all = await ref.watch(maintenanceQuoteRepositoryProvider).listAll();
  return all.where((q) => eventIds.contains(q.maintenanceEventId.value)).toList();
}

@riverpod
Future<List<MaintenanceQuote>> quotesForEvent(Ref ref, String eventId) async {
  ref.watch(storeChangesProvider);
  final all = await ref.watch(maintenanceQuoteRepositoryProvider).listAll();
  return all.where((q) => q.maintenanceEventId.value == eventId).toList();
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
  final maintenance = await ref.watch(maintenanceEventsProvider(vehicleId).future);
  final costs = await ref.watch(costEntriesProvider(vehicleId).future);
  final quotes = await ref.watch(quotesForVehicleProvider(vehicleId).future);
  final odo = await ref.watch(currentOdometerProvider(vehicleId).future);
  return FinanceService.compute(
    ownerships: ownerships,
    fuel: fuel,
    maintenance: maintenance,
    costs: costs,
    quotes: quotes,
    currentOdometer: odo,
  );
}

/// Km courant dérivé localement (MAX odometer toutes saisies).
@riverpod
Future<int?> currentOdometer(Ref ref, String vehicleId) async {
  final fuel = await ref.watch(fuelEntriesProvider(vehicleId).future);
  final events = await ref.watch(maintenanceEventsProvider(vehicleId).future);
  final tires = await ref.watch(tirePressuresProvider(vehicleId).future);
  return VehicleStatsService.currentOdometer(fuel: fuel, maintenance: events, tires: tires);
}

@riverpod
Future<double?> averageConsumption(Ref ref, String vehicleId) async {
  final fuel = await ref.watch(fuelEntriesProvider(vehicleId).future);
  return VehicleStatsService.averageConsumption(fuel);
}

/// Échéances triées par urgence (en retard, puis bientôt, puis à venir).
@riverpod
Future<List<DueTask>> dueTasks(Ref ref, String vehicleId) async {
  final tasks = await ref.watch(maintenanceTasksProvider(vehicleId).future);
  final odo = await ref.watch(currentOdometerProvider(vehicleId).future);
  final result = tasks
      .map((t) => (task: t, due: DueStatusService.compute(t, currentOdometer: odo)))
      .toList();
  int rank(DueStatus s) => switch (s) {
    DueStatus.overdue => 0,
    DueStatus.dueSoon => 1,
    DueStatus.upcoming => 2,
  };
  result.sort((a, b) => rank(a.due.status).compareTo(rank(b.due.status)));
  return result;
}
