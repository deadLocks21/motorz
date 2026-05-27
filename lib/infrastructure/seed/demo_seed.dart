import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/application/sync/sync_codec.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/maintenance_event.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';

/// Garnit le store local d'un véhicule de démonstration (une Ford Mustang GT,
/// avec pleins et entretien) — uniquement en **mode `memory`** (local-only),
/// pour que l'app installée depuis le Play Store ne s'ouvre pas sur un garage
/// vide.
///
/// Écrit **directement dans le store**, jamais dans la file de synchro : ce sont
/// des données purement locales (le mode démo a la synchro désactivée de toute
/// façon). Comme la liste des véhicules n'est pas filtrée par propriétaire, le
/// véhicule s'affiche quel que soit l'`id` (aléatoire) du compte démo connecté.
///
/// **Idempotent** : ne fait rien si le garage contient déjà un véhicule (même
/// supprimé). Préserve donc les saisies de l'utilisateur entre deux lancements
/// — le store sqflite persiste même en mode démo — et ne ressuscite pas un
/// véhicule de démo qu'il aurait effacé.
class DemoSeed {
  const DemoSeed(this._store);

  final LocalRecordStore _store;

  // IDs fixes (et non générés) pour que le seed soit déterministe et rejouable.
  static const _vehicleId = '0a5c0000-0000-4000-8000-000000000001';
  static const _ownerId = '0a5c0000-0000-4000-8000-0000000000ff';

  Future<void> ensureSeeded() async {
    final existing = await _store.query('vehicles', includeDeleted: true);
    if (existing.isNotEmpty) return;

    final vehicleId = UuidValue.parse(_vehicleId);
    await _put(vehicleCodec, _mustang(vehicleId));
    for (final fuel in _fuelEntries(vehicleId)) {
      await _put(fuelEntryCodec, fuel);
    }
    for (final event in _maintenanceEvents(vehicleId)) {
      await _put(maintenanceEventCodec, event);
    }
  }

  Future<void> _put<T>(SyncCodec<T> codec, T entity) =>
      _store.put(codec.resource, codec.toJson(entity));

  Vehicle _mustang(UuidValue id) => Vehicle(
        id: id,
        ownerUserId: UuidValue.parse(_ownerId),
        type: VehicleType.voiture,
        nickname: 'Mustang GT',
        make: 'Ford',
        model: 'Mustang',
        year: 2024,
        trim: 'GT',
        vin: '1FA6P8CF8R5123456',
        licensePlate: 'FD-123-MG',
        fuelType: FuelType.essence,
        engineCc: 5038,
        powerHp: 446,
        firstRegistrationDate: '2024-03-15',
        color: 'Rouge',
        updatedAt: DateTime.utc(2026, 5, 20, 9),
      );

  /// Huit pleins consécutifs (essence) menant à 12 567 km — le MAX des relevés,
  /// donc le km courant affiché. Conso dérivée ≈ 11,9 L/100 km (V8 5.0).
  List<FuelEntry> _fuelEntries(UuidValue vehicleId) {
    FuelEntry f(
      String suffix,
      DateTime date,
      int odometer,
      double liters,
      double pricePerLiter,
      double totalCost,
      String station,
    ) =>
        FuelEntry(
          id: UuidValue.parse('0a5c0000-0000-4000-8000-0000000f$suffix'),
          vehicleId: vehicleId,
          date: date,
          odometer: odometer,
          volumeLiters: liters,
          pricePerLiter: pricePerLiter,
          totalCost: totalCost,
          fuelType: FuelType.essence,
          station: station,
          updatedAt: date,
        );

    return [
      f('0001', DateTime.utc(2025, 8, 2), 9270, 54.8, 1.90, 104.12, 'Avia'),
      f('0002', DateTime.utc(2025, 9, 15), 9740, 55.5, 1.96, 108.78, 'TotalEnergies'),
      f('0003', DateTime.utc(2025, 10, 30), 10210, 56.9, 1.93, 109.82, 'Shell'),
      f('0004', DateTime.utc(2025, 12, 10), 10680, 55.0, 1.89, 103.95, 'Carrefour'),
      f('0005', DateTime.utc(2026, 1, 25), 11150, 56.3, 1.97, 110.91, 'Intermarché'),
      f('0006', DateTime.utc(2026, 3, 8), 11620, 57.1, 1.99, 113.63, 'BP'),
      f('0007', DateTime.utc(2026, 4, 18), 12100, 55.8, 1.92, 107.14, 'Esso Express'),
      f('0008', DateTime.utc(2026, 5, 20), 12567, 54.2, 1.95, 105.69, 'TotalEnergies Access'),
    ];
  }

  /// Trois opérations d'entretien, cohérentes en date/km avec les pleins.
  List<MaintenanceEvent> _maintenanceEvents(UuidValue vehicleId) {
    MaintenanceEvent m(
      String suffix,
      DateTime date,
      int odometer,
      String title,
      String category,
      String provider,
      double partsCost,
      double laborCost,
      String description,
    ) =>
        MaintenanceEvent(
          id: UuidValue.parse('0a5c0000-0000-4000-8000-0000000e$suffix'),
          vehicleId: vehicleId,
          date: date,
          odometer: odometer,
          title: title,
          category: category,
          description: description,
          partsCost: partsCost,
          laborCost: laborCost,
          provider: provider,
          updatedAt: date,
        );

    return [
      m(
        '0001',
        DateTime.utc(2024, 9, 12),
        4200,
        'Forfait entretien 1re année (vidange + filtres)',
        'vidange',
        'Ford Store Paris 15',
        160,
        210,
        'Huile full synthèse 5W-50, filtre à huile, filtre habitacle, inspection multipoint.',
      ),
      m(
        '0002',
        DateTime.utc(2025, 6, 20),
        8100,
        'Plaquettes de frein avant',
        'freins',
        'Speedy',
        145,
        90,
        'Plaquettes avant remplacées (usure liée à une conduite sportive).',
      ),
      m(
        '0003',
        DateTime.utc(2025, 11, 5),
        10400,
        'Pneus avant + géométrie',
        'pneumatiques',
        'Euromaster',
        460,
        110,
        '2× Michelin Pilot Sport 4S 255/40 R19, équilibrage et parallélisme.',
      ),
    ];
  }
}
