import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/offline_first_repository.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/sync_api.dart';
import 'package:motorz/infrastructure/sync/sync_cursor.dart';
import 'package:motorz/infrastructure/sync/sync_service.dart';

void main() {
  late InMemoryLocalRecordStore store;
  late InMemoryPendingQueue queue;
  late OfflineFirstRepository<FuelEntry> repo;

  final vehicleId = UuidValue.generate();

  FuelEntry sampleFuel({int odometer = 100000}) => FuelEntry(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        date: DateTime.utc(2026, 5, 1),
        odometer: odometer,
        volumeLiters: 40,
        totalCost: 72.5,
        updatedAt: DateTime.utc(2026, 5, 1),
      );

  setUp(() {
    store = InMemoryLocalRecordStore();
    queue = InMemoryPendingQueue();
    const connectivity = AlwaysOnlineConnectivityService();
    final sync = SyncService(
      api: SyncApi(Dio()),
      store: store,
      queue: queue,
      connectivity: connectivity,
      cursor: InMemorySyncCursorStore(),
      enabled: false, // pas de réseau en test
    );
    repo = OfflineFirstRepository<FuelEntry>(
      codec: fuelEntryCodec,
      store: store,
      queue: queue,
      sync: sync,
      connectivity: connectivity,
    );
  });

  test('save écrit en local et met en file de synchro', () async {
    final entry = sampleFuel();
    await repo.save(entry);

    final listed = await repo.listForVehicle(vehicleId.value);
    expect(listed, hasLength(1));
    expect(listed.first.id, entry.id);
    expect(listed.first.odometer, 100000);

    final ops = await queue.readAll();
    expect(ops, hasLength(1));
    expect(ops.first.resource, 'fuel_entries');
    expect(ops.first.entityId, entry.id.value);
  });

  test('delete pose un tombstone (exclu des lectures) et met en file', () async {
    final entry = sampleFuel();
    await repo.save(entry);
    await repo.delete(entry);

    expect(await repo.listForVehicle(vehicleId.value), isEmpty);

    // La ligne existe toujours, marquée supprimée (tombstone).
    final raw = await store.getById('fuel_entries', entry.id.value);
    expect(raw, isNotNull);
    expect(raw!['deleted_at'], isNotNull);

    final ops = await queue.readAll();
    expect(ops, hasLength(1)); // LWW : save puis delete sur la même entité
    expect(ops.first.data['deleted_at'], isNotNull);
  });

  test('la file déduplique par (resource, id) — last-write-wins', () async {
    final entry = sampleFuel(odometer: 100000);
    await repo.save(entry);
    await repo.save(entry.copyWith(odometer: 100500, updatedAt: DateTime.utc(2026, 5, 2)));

    final ops = await queue.readAll();
    expect(ops, hasLength(1));
    expect((ops.first.data['odometer'] as num).toInt(), 100500);
  });
}
