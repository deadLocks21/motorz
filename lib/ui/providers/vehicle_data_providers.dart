import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:motorz/core/application/services/diagnostic.service.dart';
import 'package:motorz/core/application/services/due_status.service.dart';
import 'package:motorz/core/application/services/finance.service.dart';
import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/application/services/tire.service.dart';
import 'package:motorz/core/application/services/vehicle_stats.service.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
import 'package:motorz/core/domain/model/diagnostic_code.dart';
import 'package:motorz/core/domain/model/diagnostic_session.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/core/domain/model/maintenance_quote.dart';
import 'package:motorz/core/domain/model/media_item.dart';
import 'package:motorz/core/domain/model/ownership.dart';
import 'package:motorz/core/domain/model/target_pressure.dart';
import 'package:motorz/core/domain/model/tire.dart';
import 'package:motorz/core/domain/model/tire_mount.dart';
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

/// Prestataires déjà saisis, tous véhicules confondus — pour l'autocomplétion du
/// champ « Prestataire » d'une opération d'entretien **et d'un devis** (on revient
/// souvent au même garage quel que soit le véhicule). Voir [rankProviders].
@riverpod
Future<List<String>> knownProviders(Ref ref) async {
  ref.watch(storeChangesProvider);
  return rankProviders(
    await ref.watch(operationRepositoryProvider).listAll(),
    quotes: await ref.watch(maintenanceQuoteRepositoryProvider).listAll(),
  );
}

/// Ordonne pour l'autocomplétion **tous** les prestataires connus (pas seulement
/// les récents) par nombre d'occurrences sur les **10 dernières saisies** (les
/// garages habituels du moment remontent), puis par fréquence globale et enfin
/// alphabétiquement pour départager. Dédoublonnage sans tenir compte de la casse
/// (« Norauto » / « norauto »), l'orthographe affichée étant la première vue.
/// Calque de [rankStations].
///
/// Les [quotes] comptent au même titre que les [operations] : qui fait tout
/// lui-même n'a que des opérations sans prestataire, et sans cela le champ d'un
/// devis ne proposerait jamais rien.
@visibleForTesting
List<String> rankProviders(
  List<Operation> operations, {
  List<MaintenanceQuote> quotes = const [],
}) {
  final entries = <({String? provider, DateTime date})>[
    for (final o in operations) (provider: o.provider, date: o.date),
    for (final q in quotes) (provider: q.provider, date: q.createdAt),
  ];

  // 10 dernières saisies par date décroissante.
  final byRecency = [...entries]..sort((a, b) => b.date.compareTo(a.date));
  final recent = <String, int>{}; // occurrences sur les 10 dernières saisies
  for (final e in byRecency.take(10)) {
    final key = e.provider?.trim().toLowerCase();
    if (key == null || key.isEmpty) continue;
    recent.update(key, (n) => n + 1, ifAbsent: () => 1);
  }

  final total = <String, int>{}; // fréquence globale (départage)
  final labels = <String, String>{}; // clé normalisée → orthographe affichée
  for (final e in entries) {
    final raw = e.provider?.trim();
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

/// Intitulés des échéances « À prévoir » du véhicule — pour l'autocomplétion du
/// champ « Pièce » d'une ligne d'entretien. Saisir une ligne au même intitulé
/// qu'une échéance la remet à zéro (rapprochement par intitulé, cf. À prévoir) :
/// on propose donc directement les échéances en attente plutôt que des postes
/// déjà saisis. Contrairement aux stations/prestataires (tous véhicules
/// confondus), les échéances sont propres au véhicule. Voir [rankDueTitles] pour
/// l'ordre.
@riverpod
Future<List<String>> knownPartLabels(Ref ref, String vehicleId) async {
  return rankDueTitles(await ref.watch(duePlansProvider(vehicleId).future));
}

/// Ordonne les intitulés d'échéances pour l'autocomplétion **dans l'ordre de
/// l'onglet À prévoir** : d'abord celles « à réaliser » (en retard, bientôt dues,
/// ou tâches ponctuelles sans déclencheur), puis les « prochaines échéances » (à
/// venir avec déclencheur) — chaque groupe gardant l'ordre d'urgence de
/// [duePlans]. Dédoublonnage insensible à la casse, première orthographe
/// conservée. La partition « à réaliser / prochaines » est celle de `_TasksTab`
/// (onglet À prévoir) : garder les deux synchronisées.
@visibleForTesting
List<String> rankDueTitles(List<DuePlan> items) {
  bool isUpcomingScheduled(DuePlan d) =>
      d.due.status == DueStatus.upcoming && d.due.hasTrigger;
  final ordered = [
    ...items.where((d) => !isUpcomingScheduled(d)), // « à réaliser »
    ...items.where(isUpcomingScheduled), // « prochaines échéances »
  ];
  final seen = <String>{};
  final result = <String>[];
  for (final d in ordered) {
    final raw = d.plan.title.trim();
    if (raw.isEmpty) continue;
    if (seen.add(raw.toLowerCase())) result.add(raw);
  }
  return result;
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

/// Inventaire de pneus du véhicule (montés + en stock).
@riverpod
Future<List<Tire>> tires(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final list = await ref.watch(tireRepositoryProvider).listForVehicle(vehicleId);
  list.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
  return list;
}

/// Journal de montages du véhicule (intervalles ouverts = pneus montés).
@riverpod
Future<List<TireMount>> tireMounts(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  return ref.watch(tireMountRepositoryProvider).listForVehicle(vehicleId);
}

/// Parc de pneus prêt à afficher : pneu monté par position + inventaire ordonné
/// (montés d'abord, puis stock par saison/marque) avec km roulés dérivés.
typedef TireInventoryRow = ({Tire tire, String? position, int? kmRolled});
typedef TireFleet = ({
  Map<String, MountedTire> byPosition,
  List<TireInventoryRow> inventory, // en service / en stock
  List<TireInventoryRow> disposed, // au rebut (gardés pour l'historique)
  int? currentOdometer,
});

@riverpod
Future<TireFleet> tireFleet(Ref ref, String vehicleId) async {
  final tires = await ref.watch(tiresProvider(vehicleId).future);
  final mounts = await ref.watch(tireMountsProvider(vehicleId).future);
  final odo = await ref.watch(currentOdometerProvider(vehicleId).future);
  final byPosition = TireService.mountedByPosition(tires, mounts, odo);
  final positionByTire = <String, String>{
    for (final entry in byPosition.entries) entry.value.tire.id.value: entry.key,
  };
  final rows = [
    for (final t in tires)
      (
        tire: t,
        position: positionByTire[t.id.value],
        kmRolled: TireService.kmRolled(t.id.value, mounts, odo),
      ),
  ]..sort(_compareInventoryRows);
  return (
    byPosition: byPosition,
    inventory: [for (final r in rows) if (!r.tire.isDisposed) r],
    disposed: [for (final r in rows) if (r.tire.isDisposed) r],
    currentOdometer: odo,
  );
}

const _positionOrder = ['AVG', 'AVD', 'ARG', 'ARD', 'AV', 'AR', 'SEC'];
int _positionRank(String? p) {
  if (p == null) return 1000; // stock après les montés
  final i = _positionOrder.indexOf(p);
  return i < 0 ? 999 : i;
}

int _seasonRank(TireSeason? s) => switch (s) {
  TireSeason.ete => 0,
  TireSeason.hiver => 1,
  TireSeason.quatreSaisons => 2,
  TireSeason.circuit => 3,
  null => 4,
};

int _compareInventoryRows(TireInventoryRow a, TireInventoryRow b) {
  final byPos = _positionRank(a.position).compareTo(_positionRank(b.position));
  if (byPos != 0) return byPos;
  final bySeason = _seasonRank(a.tire.season).compareTo(_seasonRank(b.tire.season));
  if (bySeason != 0) return bySeason;
  return a.tire.displayName.toLowerCase().compareTo(b.tire.displayName.toLowerCase());
}

/// Marques de pneus déjà saisies (tous véhicules) — autocomplétion du champ
/// « Marque ». Voir [rankTireBrands].
@riverpod
Future<List<String>> knownTireBrands(Ref ref) async {
  ref.watch(storeChangesProvider);
  return rankTireBrands(await ref.watch(tireRepositoryProvider).listAll());
}

@visibleForTesting
List<String> rankTireBrands(List<Tire> tires) => _rankByFrequency(tires.map((t) => t.brand));

/// Tailles de pneus déjà saisies (tous véhicules) — autocomplétion du champ
/// « Taille ». Voir [rankTireSizes].
@riverpod
Future<List<String>> knownTireSizes(Ref ref) async {
  ref.watch(storeChangesProvider);
  return rankTireSizes(await ref.watch(tireRepositoryProvider).listAll());
}

@visibleForTesting
List<String> rankTireSizes(List<Tire> tires) => _rankByFrequency(tires.map((t) => t.size));

/// Ordonne des valeurs de champ libre pour l'autocomplétion : fréquence globale
/// décroissante puis alphabétique, dédoublonnage insensible à la casse (première
/// orthographe conservée). Calque allégé de [rankStations] — pas de notion de
/// récence (marque/taille de pneu varient peu dans le temps).
List<String> _rankByFrequency(Iterable<String?> values) {
  final total = <String, int>{};
  final labels = <String, String>{};
  for (final raw in values) {
    final v = raw?.trim();
    if (v == null || v.isEmpty) continue;
    final key = v.toLowerCase();
    total.update(key, (n) => n + 1, ifAbsent: () => 1);
    labels.putIfAbsent(key, () => v);
  }
  final keys = labels.keys.toList()
    ..sort((a, b) {
      final byTotal = total[b]!.compareTo(total[a]!);
      return byTotal != 0 ? byTotal : a.compareTo(b);
    });
  return [for (final k in keys) labels[k]!];
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

// ── Diagnostics (OBD & batterie) ────────────────────────────────────────────

/// Sessions de diagnostic d'un véhicule, de la plus récente à la plus ancienne.
@riverpod
Future<List<DiagnosticSession>> diagnosticSessions(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final list = await ref.watch(diagnosticSessionRepositoryProvider).listForVehicle(vehicleId);
  list.sort((a, b) => b.date.compareTo(a.date));
  return list;
}

/// Codes défaut d'une session (bruts : un par calculateur ayant remonté le
/// code — cf. [DiagnosticService.groupBySession] pour l'affichage).
@riverpod
Future<List<DiagnosticCode>> codesForSession(Ref ref, String sessionId) async {
  ref.watch(storeChangesProvider);
  final all = await ref.watch(diagnosticCodeRepositoryProvider).listAll();
  return all.where((c) => c.sessionId.value == sessionId).toList();
}

/// Tous les codes du véhicule, toutes sessions confondues.
@riverpod
Future<List<DiagnosticCode>> codesForVehicle(Ref ref, String vehicleId) async {
  ref.watch(storeChangesProvider);
  final sessions = await ref.watch(diagnosticSessionsProvider(vehicleId).future);
  final sessionIds = sessions.map((s) => s.id.value).toSet();
  final all = await ref.watch(diagnosticCodeRepositoryProvider).listAll();
  return all.where((c) => sessionIds.contains(c.sessionId.value)).toList();
}

/// Histoire de chaque code du véhicule (actif / non revérifié / disparu),
/// dérivée de l'historique des sessions.
@riverpod
Future<List<CodeHistory>> diagnosticHistory(Ref ref, String vehicleId) async {
  final sessions = await ref.watch(diagnosticSessionsProvider(vehicleId).future);
  final codes = await ref.watch(codesForVehicleProvider(vehicleId).future);
  return DiagnosticService.history(sessions, codes);
}

/// Défauts encore actifs — l'indicateur in-app du véhicule (§5.10).
@riverpod
Future<List<CodeHistory>> activeDiagnosticCodes(Ref ref, String vehicleId) async {
  final all = await ref.watch(diagnosticHistoryProvider(vehicleId).future);
  return all.where((h) => h.isActive).toList();
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
  final mounts = await ref.watch(tireMountsProvider(vehicleId).future);
  return VehicleStatsService.currentOdometer(
      fuel: fuel, operations: ops, tires: tires, mounts: mounts);
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
