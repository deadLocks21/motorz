import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/infrastructure/connectivity/connectivity_plus.service.dart';
import 'package:motorz/infrastructure/providers/infra_providers.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/ui/pages/vehicle_detail/vehicle_detail.page.dart';
import 'package:motorz/ui/theme/app_theme_data.dart';

/// Store avec latence de lecture : reproduit le comportement sqflite réel, où un
/// reload traverse une frame en état *loading* (l'InMemory pur résout en un
/// microtask et masquerait le bug). Indispensable pour que ce test discrimine.
class _LatentStore implements LocalRecordStore {
  _LatentStore(this._inner);
  final LocalRecordStore _inner;
  static const _latency = Duration(milliseconds: 30);

  @override
  Stream<int> get changes => _inner.changes;
  @override
  Future<void> put(String r, Map<String, dynamic> row) => _inner.put(r, row);
  @override
  Future<void> upsertAll(String r, List<Map<String, dynamic>> rows) => _inner.upsertAll(r, rows);

  @override
  Future<Map<String, dynamic>?> getById(String r, String id) async {
    await Future<void>.delayed(_latency);
    return _inner.getById(r, id);
  }

  @override
  Future<List<Map<String, dynamic>>> query(String r, {String? vehicleId, bool includeDeleted = false}) async {
    await Future<void>.delayed(_latency);
    return _inner.query(r, vehicleId: vehicleId, includeDeleted: includeDeleted);
  }
}

int _selectedTab(WidgetTester tester) =>
    tester.widget<TabBar>(find.byType(TabBar)).controller!.index;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('un save ne réinitialise pas l\'onglet de la page détail', (tester) async {
    final inner = InMemoryLocalRecordStore();
    final store = _LatentStore(inner);
    final vehicle = Vehicle(
      id: UuidValue.generate(),
      ownerUserId: UuidValue.generate(),
      type: VehicleType.voiture,
      nickname: 'La 308',
      make: 'Peugeot',
      updatedAt: DateTime.utc(2026, 5, 1),
    );
    await inner.put('vehicles', vehicleCodec.toJson(vehicle));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localRecordStoreProvider.overrideWithValue(store),
          connectivityServiceProvider.overrideWithValue(const AlwaysOnlineConnectivityService()),
          currentSessionProvider.overrideWithValue(null),
        ],
        child: MaterialApp(
          theme: AppThemeData.buildLightTheme(),
          home: VehicleDetailPage(vehicleId: vehicle.id.value),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // L'utilisateur passe sur l'onglet « Pleins » (index 1).
    await tester.tap(find.text('Pleins'));
    await tester.pumpAndSettle();
    expect(_selectedTab(tester), 1);

    // Simule un save : n'importe quelle écriture fait émettre storeChanges →
    // vehicleByIdProvider reload (lecture latente → frame *loading*). Sans
    // skipLoadingOnReload, `.when` rejoue `loading`, détruit _VehicleDetailView
    // et recrée le TabController à 0.
    await inner.put('vehicles', {
      ...vehicleCodec.toJson(vehicle),
      'updated_at': DateTime.utc(2026, 5, 2).toIso8601String(),
    });
    await tester.pump(); // livre l'event stream → frame en état *loading*
    await tester.pumpAndSettle(); // laisse la lecture latente se terminer

    expect(
      _selectedTab(tester),
      1,
      reason: 'le save ne doit pas détruire la page et la ramener sur « Vue d\'ensemble »',
    );
  });
}
