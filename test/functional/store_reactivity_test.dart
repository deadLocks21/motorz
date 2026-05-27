import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';

/// Sonde reproduisant le contrat des providers de `vehicle_data_providers.dart` :
/// elle `watch` [storeChangesProvider] puis relit le store. Si la réactivité est
/// correcte, elle se recalcule à *chaque* écriture.
final _vehicleCount = FutureProvider.autoDispose<int>((ref) async {
  ref.watch(storeChangesProvider);
  final rows = await ref.watch(localRecordStoreProvider).query('vehicles');
  return rows.length;
});

void main() {
  test('un consommateur de storeChanges se rebuild à CHAQUE écriture, pas qu\'à la 1ʳᵉ', () async {
    final store = InMemoryLocalRecordStore();
    final container = ProviderContainer(
      overrides: [localRecordStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final seen = <int>[];
    container.listen<AsyncValue<int>>(
      _vehicleCount,
      (_, next) {
        if (next case AsyncData(:final value)) seen.add(value);
      },
      fireImmediately: true,
    );

    // Laisse le calcul initial émettre (0).
    await container.read(_vehicleCount.future);

    Future<void> addVehicle(String id) async {
      final iso = DateTime.now().toUtc().toIso8601String();
      await store.put('vehicles', {'id': id, 'updated_at': iso});
      // Propagation : event broadcast → storeChangesProvider → invalidation → rebuild async.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    await addVehicle('v1');
    await addVehicle('v2');
    await addVehicle('v3');

    // Régression visée : avec l'ancien `Stream<void>`, chaque émission valait
    // `AsyncData(null)`, dédoublonné par Riverpod (`updateShouldNotify` →
    // `prev != next`) — seule la 1ʳᵉ écriture rebuildait, donc `seen` resterait
    // [0, 1]. La révision monotone fait diverger les états → rebuild à chaque fois.
    expect(
      seen,
      containsAllInOrder(<int>[0, 1, 2, 3]),
      reason: 'storeChanges doit renotifier à chaque écriture (révision monotone)',
    );
  });
}
