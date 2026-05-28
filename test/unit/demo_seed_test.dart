import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/vehicle_stats.service.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/infrastructure/seed/demo_seed.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';

void main() {
  late InMemoryLocalRecordStore store;
  final owner = UuidValue.generate();

  setUp(() => store = InMemoryLocalRecordStore());

  Future<List<Vehicle>> vehicles() async =>
      (await store.query('vehicles')).map(vehicleCodec.fromJson).toList();

  test('garnit le garage : Mustang GT + pleins + catalogue + opérations + plans', () async {
    await DemoSeed(store, owner).ensureSeeded();

    final cars = await vehicles();
    expect(cars, hasLength(1));
    final mustang = cars.single;
    expect(mustang.make, 'Ford');
    expect(mustang.model, 'Mustang');
    expect(mustang.year, 2024);
    expect(mustang.licensePlate, 'FD-123-MG');
    expect(mustang.ownerUserId, owner, reason: 'le seed est rattaché au compte connecté');

    final fuel = (await store.query('fuel_entries')).map(fuelEntryCodec.fromJson).toList();
    final catalog =
        (await store.query('maintenance_catalog_items')).map(catalogItemCodec.fromJson).toList();
    final operations =
        (await store.query('maintenance_operations')).map(operationCodec.fromJson).toList();
    final lines = (await store.query('maintenance_operation_lines'))
        .map(operationLineCodec.fromJson)
        .toList();
    final plans = (await store.query('maintenance_plans')).map(planCodec.fromJson).toList();

    expect(fuel, hasLength(8));
    expect(catalog, hasLength(7));
    expect(operations, hasLength(3));
    expect(lines, hasLength(5));
    expect(plans, hasLength(3));

    // « Elle a 12 567 km » = MAX(odometer) de toutes les saisies.
    expect(
      VehicleStatsService.currentOdometer(fuel: fuel, operations: operations),
      12567,
    );
    // Conso dérivée plausible pour un V8 5.0 (ignore le 1er plein).
    expect(VehicleStatsService.averageConsumption(fuel), closeTo(11.9, 0.3));
  });

  test('idempotent : ne ré-injecte pas si un véhicule existe déjà', () async {
    await DemoSeed(store, owner).ensureSeeded();
    await DemoSeed(store, owner).ensureSeeded();
    expect(await vehicles(), hasLength(1));
  });

  test('ne ressuscite pas un véhicule de démo supprimé (tombstone)', () async {
    await DemoSeed(store, owner).ensureSeeded();
    final mustang = (await vehicles()).single;

    // L'utilisateur supprime le véhicule de démo → tombstone.
    final nowIso = DateTime.now().toUtc().toIso8601String();
    await store.put('vehicles', {
      ...vehicleCodec.toJson(mustang),
      'deleted_at': nowIso,
      'updated_at': nowIso,
    });

    await DemoSeed(store, owner).ensureSeeded();
    expect(await vehicles(), isEmpty); // reste supprimé
  });
}
