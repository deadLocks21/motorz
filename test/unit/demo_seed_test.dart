import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/tire.service.dart';
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
    final operations =
        (await store.query('maintenance_operations')).map(operationCodec.fromJson).toList();
    final lines = (await store.query('maintenance_operation_lines'))
        .map(operationLineCodec.fromJson)
        .toList();
    final plans = (await store.query('maintenance_plans')).map(planCodec.fromJson).toList();

    final tires = (await store.query('tires')).map(tireCodec.fromJson).toList();
    final mounts = (await store.query('tire_mounts')).map(tireMountCodec.fromJson).toList();

    expect(fuel, hasLength(8));
    expect(operations, hasLength(3));
    expect(lines, hasLength(5));
    expect(plans, hasLength(4));
    // Jeu été (6 PS4S : 2 AV + 2 AR déposés + 2 AR neufs) + galette + jeu hiver (4).
    expect(tires, hasLength(11));
    expect(mounts, hasLength(7));
    // Les 2 arrière d'origine sont partis à la benne (au rebut), gardés en historique.
    expect(tires.where((t) => t.isDisposed).length, 2);

    // « Elle a 12 567 km » = MAX(odometer) de toutes les saisies, montages inclus.
    expect(
      VehicleStatsService.currentOdometer(fuel: fuel, operations: operations, mounts: mounts),
      12567,
    );
    // Conso dérivée plausible pour un V8 5.0 (ignore le 1er plein).
    expect(VehicleStatsService.averageConsumption(fuel), closeTo(11.9, 0.3));

    // Km roulés dérivés du journal : avant depuis la livraison (~12,5k), arrière
    // neufs depuis 10 400 km (~2,2k), anciens arrière figés à leur dépose, galette
    // exclue (ne roule pas).
    String tireId(String s) => '0a5c0000-0000-4000-8000-0000000a$s';
    expect(TireService.kmRolled(tireId('0001'), mounts, 12567), 12517); // AVG d'origine
    expect(TireService.kmRolled(tireId('0005'), mounts, 12567), 2167); // AR neuf
    expect(TireService.kmRolled(tireId('0003'), mounts, 12567), 10350); // AR déposé
    expect(TireService.kmRolled(tireId('0007'), mounts, 12567), isNull); // galette (SEC)

    // Monte courante : 4 roues + secours occupés ; l'arrière gauche porte le pneu
    // neuf (0005), pas l'ancien (0003).
    final byPosition = TireService.mountedByPosition(tires, mounts, 12567);
    expect(byPosition.keys, containsAll(['AVG', 'AVD', 'ARG', 'ARD', 'SEC']));
    expect(byPosition['ARG']!.tire.id.value, tireId('0005'));
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
