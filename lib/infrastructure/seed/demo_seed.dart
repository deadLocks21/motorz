import 'package:motorz/core/application/sync/entity_codecs.dart';
import 'package:motorz/core/application/sync/sync_codec.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';

/// Garnit le store local d'un véhicule de démonstration (une Ford Mustang GT,
/// avec pleins, opérations à lignes et échéances) — appelé **au login en mode
/// `memory`** (local-only), pour que l'app installée depuis le Play Store ne
/// s'ouvre pas sur un garage vide.
///
/// Les données sont rattachées au compte démo connecté ([_ownerId] = l'`id` de la
/// session, déterministe en local-only), si bien que la Mustang apparaît sous
/// « Mes véhicules ».
///
/// Écrit **directement dans le store**, jamais dans la file de synchro : ce sont
/// des données purement locales (le mode démo a la synchro désactivée de toute façon).
///
/// **Idempotent** : ne fait rien si le garage contient déjà un véhicule (même
/// supprimé). Préserve donc les saisies de l'utilisateur tant qu'il reste connecté
/// (la déconnexion purge le store) et ne ressuscite pas un véhicule qu'il a effacé.
class DemoSeed {
  const DemoSeed(this._store, this._ownerId);

  final LocalRecordStore _store;

  /// Propriétaire des données semées : l'`id` du compte démo connecté.
  final UuidValue _ownerId;

  // IDs fixes (et non générés) pour que le seed soit déterministe et rejouable.
  static const _vehicleId = '0a5c0000-0000-4000-8000-000000000001';

  Future<void> ensureSeeded() async {
    final existing = await _store.query('vehicles', includeDeleted: true);
    if (existing.isNotEmpty) return;

    final vehicleId = UuidValue.parse(_vehicleId);
    await _put(vehicleCodec, _mustang(vehicleId));
    for (final fuel in _fuelEntries(vehicleId)) {
      await _put(fuelEntryCodec, fuel);
    }
    for (final op in _operations(vehicleId)) {
      await _put(operationCodec, op);
    }
    for (final l in _lines()) {
      await _put(operationLineCodec, l);
    }
    for (final p in _plans(vehicleId)) {
      await _put(planCodec, p);
    }
  }

  Future<void> _put<T>(SyncCodec<T> codec, T entity) =>
      _store.put(codec.resource, codec.toJson(entity));

  Vehicle _mustang(UuidValue id) => Vehicle(
        id: id,
        ownerUserId: _ownerId,
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

  static final _seedAt = DateTime.utc(2026, 5, 20, 9);

  /// Trois opérations (en-têtes), cohérentes en date/km avec les pleins.
  List<Operation> _operations(UuidValue vehicleId) {
    Operation o(String suffix, DateTime date, int odometer, String provider, String note) =>
        Operation(
          id: UuidValue.parse('0a5c0000-0000-4000-8000-0000000e$suffix'),
          vehicleId: vehicleId,
          date: date,
          odometer: odometer,
          provider: provider,
          note: note,
          updatedAt: date,
        );

    return [
      o('0001', DateTime.utc(2024, 9, 12), 4200, 'Ford Store Paris 15',
          'Huile full synthèse 5W-50, filtre habitacle, inspection multipoint.'),
      o('0002', DateTime.utc(2025, 6, 20), 8100, 'Speedy',
          'Plaquettes avant remplacées (usure liée à une conduite sportive).'),
      o('0003', DateTime.utc(2025, 11, 5), 10400, 'Euromaster',
          '2× Michelin Pilot Sport 4S 255/40 R19, équilibrage et parallélisme.'),
    ];
  }

  /// Lignes des opérations (postes faits, en libellé libre). Les intitulés
  /// « Vidange » correspondent au titre de l'échéance → la remettent à zéro.
  List<OperationLine> _lines() {
    OperationLine line(String suffix, String opSuffix, String label,
            {double? parts, double? labor}) =>
        OperationLine(
          id: UuidValue.parse('0a5c0000-0000-4000-8000-0000000d$suffix'),
          operationId: UuidValue.parse('0a5c0000-0000-4000-8000-0000000e$opSuffix'),
          label: label,
          partsCost: parts,
          laborCost: labor,
          updatedAt: _seedAt,
        );

    return [
      // Op1 : vidange + filtre habitacle (370 € au total).
      line('0001', '0001', 'Vidange', parts: 120, labor: 150),
      line('0002', '0001', 'Filtre habitacle', parts: 40, labor: 60),
      // Op2 : plaquettes (235 €).
      line('0003', '0002', 'Plaquettes de frein', parts: 145, labor: 90),
      // Op3 : pneus + une ligne libre (570 €).
      line('0004', '0003', 'Pneumatiques', parts: 460, labor: 80),
      line('0005', '0003', 'Géométrie / parallélisme', labor: 30),
    ];
  }

  /// Échéances. Récurrentes : Vidange (dernière réalisation dérivée de l'opération
  /// de 2024, dont une ligne s'intitule « Vidange ») et CT (avec amorce datée).
  /// Ponctuelles (sans intervalle) : Distribution (cible km, → Prochaines
  /// échéances) et un petit à-faire sans date (→ À réaliser).
  List<Plan> _plans(UuidValue vehicleId) {
    return [
      Plan(
        id: UuidValue.parse('0a5c0000-0000-4000-8000-0000000b0001'),
        vehicleId: vehicleId,
        title: 'Vidange',
        intervalKm: 15000,
        intervalMonths: 12,
        updatedAt: _seedAt,
      ),
      Plan(
        id: UuidValue.parse('0a5c0000-0000-4000-8000-0000000b0002'),
        vehicleId: vehicleId,
        title: 'Contrôle technique',
        intervalMonths: 24,
        dueDate: '2026-09-01',
        updatedAt: _seedAt,
      ),
      Plan(
        id: UuidValue.parse('0a5c0000-0000-4000-8000-0000000b0003'),
        vehicleId: vehicleId,
        title: 'Distribution',
        dueOdometer: 120000,
        updatedAt: _seedAt,
      ),
      Plan(
        id: UuidValue.parse('0a5c0000-0000-4000-8000-0000000b0004'),
        vehicleId: vehicleId,
        title: 'Changer l\'ampoule de plaque',
        updatedAt: _seedAt,
      ),
    ];
  }
}
