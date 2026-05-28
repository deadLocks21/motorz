import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/application/sync/sync_codec.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
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
import 'package:motorz/core/domain/services/syncable.repository.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/sync/offline_first_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'repository_providers.g.dart';

OfflineFirstRepository<T> _build<T>(Ref ref, SyncCodec<T> codec) => OfflineFirstRepository<T>(
      codec: codec,
      store: ref.watch(localRecordStoreProvider),
      queue: ref.watch(pendingQueueProvider),
      sync: ref.watch(syncServiceProvider),
      connectivity: ref.watch(connectivityServiceProvider),
    );

@riverpod
SyncableRepository<Vehicle> vehicleRepository(Ref ref) => _build(ref, vehicleCodec);

@riverpod
SyncableRepository<FuelEntry> fuelRepository(Ref ref) => _build(ref, fuelEntryCodec);

@riverpod
SyncableRepository<CatalogItem> catalogItemRepository(Ref ref) =>
    _build(ref, catalogItemCodec);

@riverpod
SyncableRepository<Operation> operationRepository(Ref ref) => _build(ref, operationCodec);

@riverpod
SyncableRepository<OperationLine> operationLineRepository(Ref ref) =>
    _build(ref, operationLineCodec);

@riverpod
SyncableRepository<Plan> planRepository(Ref ref) => _build(ref, planCodec);

@riverpod
SyncableRepository<TirePressureEntry> tirePressureRepository(Ref ref) =>
    _build(ref, tirePressureCodec);

@riverpod
SyncableRepository<TargetPressure> targetPressureRepository(Ref ref) =>
    _build(ref, targetPressureCodec);

@riverpod
SyncableRepository<Ownership> ownershipRepository(Ref ref) => _build(ref, ownershipCodec);

@riverpod
SyncableRepository<CostEntry> costEntryRepository(Ref ref) => _build(ref, costEntryCodec);

@riverpod
SyncableRepository<MaintenanceQuote> maintenanceQuoteRepository(Ref ref) =>
    _build(ref, maintenanceQuoteCodec);

@riverpod
SyncableRepository<MediaItem> mediaRepository(Ref ref) => _build(ref, mediaItemCodec);
