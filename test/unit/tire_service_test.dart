import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/tire.service.dart';
import 'package:motorz/core/domain/model/tire.dart';
import 'package:motorz/core/domain/model/tire_mount.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Dérivations du parc de pneus : km roulés (somme des intervalles, secours
/// exclu) et transitions montage/démontage.
void main() {
  final vehicleId = UuidValue.generate();
  final now = DateTime.utc(2026, 6, 1);

  // IDs fixes (UUID v4 valides).
  const t1 = '11111111-1111-4111-8111-111111111111';
  const t2 = '22222222-2222-4222-8222-222222222222';
  const t3 = '33333333-3333-4333-8333-333333333333';
  const m1 = 'aaaaaaaa-1111-4111-8111-111111111111';
  const m2 = 'bbbbbbbb-2222-4222-8222-222222222222';
  const m3 = 'cccccccc-3333-4333-8333-333333333333';

  Tire tire(String id) => Tire(id: UuidValue.parse(id), vehicleId: vehicleId, updatedAt: now);
  TireMount mount(
    String id,
    String tireId,
    String position,
    int from, {
    int? to,
    bool deleted = false,
  }) =>
      TireMount(
        id: UuidValue.parse(id),
        vehicleId: vehicleId,
        tireId: UuidValue.parse(tireId),
        position: position,
        mountedOdometer: from,
        dismountedOdometer: to,
        updatedAt: now,
        deletedAt: deleted ? now : null,
      );

  group('kmRolled', () {
    test('intervalle ouvert : du montage au km courant', () {
      expect(TireService.kmRolled(t1, [mount(m1, t1, 'AVG', 1000)], 5000), 4000);
    });

    test('somme de plusieurs intervalles (déposé puis remonté ailleurs)', () {
      final mounts = [
        mount(m1, t1, 'AVG', 1000, to: 3000),
        mount(m2, t1, 'ARG', 3000),
      ];
      expect(TireService.kmRolled(t1, mounts, 5000), 4000); // 2000 + 2000
    });

    test('la roue de secours (SEC) ne compte pas', () {
      expect(TireService.kmRolled(t1, [mount(m1, t1, 'SEC', 1000)], 5000), isNull);
    });

    test('ignore les intervalles supprimés', () {
      expect(TireService.kmRolled(t1, [mount(m1, t1, 'AVG', 1000, deleted: true)], 5000), isNull);
    });

    test('null si aucun intervalle pour ce pneu', () {
      expect(TireService.kmRolled(t1, [mount(m1, t2, 'AVG', 1000)], 5000), isNull);
    });

    test('null si encore monté mais km courant inconnu', () {
      expect(TireService.kmRolled(t1, [mount(m1, t1, 'AVG', 1000)], null), isNull);
    });

    test('intervalle incohérent (démontage < montage) compté pour 0', () {
      expect(TireService.kmRolled(t1, [mount(m1, t1, 'AVG', 5000, to: 4000)], 6000), 0);
    });
  });

  group('mountAtPosition / currentMountFor', () {
    test('renvoie l\'intervalle ouvert occupant la position / portant le pneu', () {
      final open = mount(m1, t1, 'ARG', 1000);
      final closed = mount(m2, t2, 'ARG', 0, to: 1000);
      final mounts = [open, closed];
      expect(TireService.mountAtPosition('ARG', mounts), open);
      expect(TireService.currentMountFor(t1, mounts), open);
      expect(TireService.mountAtPosition('AVG', mounts), isNull);
      expect(TireService.currentMountFor(t2, mounts), isNull);
    });
  });

  group('planMount', () {
    test('position vide : ouvre un seul intervalle', () {
      final writes = TireService.planMount(
        vehicleId: vehicleId,
        tireId: t1,
        position: 'ARG',
        odometer: 5000,
        mounts: const [],
        now: now,
      );
      expect(writes, hasLength(1));
      final w = writes.single;
      expect(w.tireId.value, t1);
      expect(w.position, 'ARG');
      expect(w.mountedOdometer, 5000);
      expect(w.dismountedOdometer, isNull);
    });

    test('déloge le pneu présent (→ stock) et ouvre le nouveau', () {
      final writes = TireService.planMount(
        vehicleId: vehicleId,
        tireId: t1,
        position: 'ARG',
        odometer: 5000,
        mounts: [mount(m1, t2, 'ARG', 1000)],
        now: now,
      );
      expect(writes, hasLength(2));
      final closed = writes.firstWhere((w) => w.tireId.value == t2);
      expect(closed.id.value, m1, reason: 'même intervalle, simplement fermé');
      expect(closed.dismountedOdometer, 5000);
      final opened = writes.firstWhere((w) => w.tireId.value == t1);
      expect(opened.position, 'ARG');
      expect(opened.dismountedOdometer, isNull);
    });

    test('rotation : démonte le pneu de son ancienne position avant de le remonter', () {
      final writes = TireService.planMount(
        vehicleId: vehicleId,
        tireId: t1,
        position: 'ARG',
        odometer: 5000,
        mounts: [mount(m1, t1, 'AVG', 2000)],
        now: now,
      );
      expect(writes, hasLength(2));
      final closed = writes.firstWhere((w) => w.id.value == m1);
      expect(closed.position, 'AVG');
      expect(closed.dismountedOdometer, 5000);
      expect(writes.any((w) => w.position == 'ARG' && w.dismountedOdometer == null), isTrue);
    });

    test('déloge ET déplace (3 écritures)', () {
      final writes = TireService.planMount(
        vehicleId: vehicleId,
        tireId: t1,
        position: 'ARG',
        odometer: 5000,
        mounts: [mount(m1, t2, 'ARG', 1000), mount(m2, t1, 'AVG', 2000)],
        now: now,
      );
      expect(writes, hasLength(3));
      expect(writes.where((w) => w.dismountedOdometer == 5000), hasLength(2)); // 2 fermetures
      expect(writes.where((w) => w.dismountedOdometer == null), hasLength(1)); // 1 ouverture
    });

    test('no-op si le pneu est déjà monté à cette position', () {
      final writes = TireService.planMount(
        vehicleId: vehicleId,
        tireId: t1,
        position: 'ARG',
        odometer: 5000,
        mounts: [mount(m1, t1, 'ARG', 1000)],
        now: now,
      );
      expect(writes, isEmpty);
    });
  });

  group('planDismount', () {
    test('ferme l\'intervalle ouvert de la position', () {
      final writes = TireService.planDismount(
        position: 'ARG',
        odometer: 5000,
        mounts: [mount(m1, t1, 'ARG', 1000)],
        now: now,
      );
      expect(writes, hasLength(1));
      expect(writes.single.id.value, m1);
      expect(writes.single.dismountedOdometer, 5000);
    });

    test('rien à démonter → aucune écriture', () {
      expect(
        TireService.planDismount(position: 'ARG', odometer: 5000, mounts: const [], now: now),
        isEmpty,
      );
    });
  });

  group('vehicleChanges', () {
    test('regroupe par (km) et trie du plus récent ; montés + déposés', () {
      final tires = [tire(t1), tire(t2), tire(t3)];
      final mounts = [
        mount(m1, t1, 'AVG', 50), // monté à la livraison, encore en place
        mount(m2, t2, 'ARG', 50, to: 10400), // arrière d'origine, déposé à 10 400
        mount(m3, t3, 'ARG', 10400), // arrière neuf monté à 10 400
      ];
      final changes = TireService.vehicleChanges(tires, mounts);

      expect(changes, hasLength(2));
      // Plus récent d'abord : le remplacement à 10 400 km.
      expect(changes[0].odometer, 10400);
      expect(changes[0].mounted.map((e) => e.tire.id.value), [t3]);
      expect(changes[0].mounted.single.position, 'ARG');
      expect(changes[0].dismounted.map((e) => e.tire.id.value), [t2]);
      // Puis la pose initiale (50 km) : 2 montés, rien de déposé.
      expect(changes[1].odometer, 50);
      expect(changes[1].mounted.map((e) => e.position), containsAll(['AVG', 'ARG']));
      expect(changes[1].dismounted, isEmpty);
    });

    test('ignore les intervalles supprimés', () {
      final mounts = [mount(m1, t1, 'AVG', 50, deleted: true)];
      expect(TireService.vehicleChanges([tire(t1)], mounts), isEmpty);
    });
  });
}
