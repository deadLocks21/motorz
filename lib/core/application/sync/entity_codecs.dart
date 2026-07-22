import 'package:motorz/core/application/sync/sync_codec.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
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
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/model/vehicle.dart';

UuidValue _id(Object? v) => UuidValue.parse(v as String);
UuidValue? _idN(Object? v) => v == null ? null : UuidValue.parse(v as String);

/// Lecture défensive d'un champ texte devenu requis : tolère les enregistrements
/// locaux d'un ancien format (où le champ pouvait être `null`) en repliant sur un
/// libellé par défaut, plutôt que de crasher au cast.
String _strOr(Object? v, String fallback) {
  final s = v as String?;
  return (s == null || s.trim().isEmpty) ? fallback : s;
}

final vehicleCodec = SyncCodec<Vehicle>(
  resource: 'vehicles',
  idOf: (v) => v.id.value,
  vehicleIdOf: (v) => v.id.value,
  updatedAtOf: (v) => v.updatedAt,
  deletedAtOf: (v) => v.deletedAt,
  fromJson: (m) => Vehicle(
    id: _id(m['id']),
    ownerUserId: _id(m['owner_user_id']),
    shareCode: m['share_code'] as String?,
    type: VehicleType.fromWire(m['type'] as String),
    nickname: m['nickname'] as String,
    make: m['make'] as String?,
    model: m['model'] as String?,
    year: intOrNull(m['year']),
    trim: m['trim'] as String?,
    vin: m['vin'] as String?,
    licensePlate: m['license_plate'] as String?,
    fuelType: FuelType.fromWire(m['fuel_type'] as String?),
    engineCc: intOrNull(m['engine_cc']),
    powerHp: intOrNull(m['power_hp']),
    firstRegistrationDate: m['first_registration_date'] as String?,
    color: m['color'] as String?,
    photoMediaId: _idN(m['photo_media_id']),
    tireMonthlyLossBar: doubleOrNull(m['tire_monthly_loss_bar']),
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (v) => {
    'id': v.id.value,
    'owner_user_id': v.ownerUserId.value,
    if (v.shareCode != null) 'share_code': v.shareCode,
    'type': v.type.wire,
    'nickname': v.nickname,
    'make': v.make,
    'model': v.model,
    'year': v.year,
    'trim': v.trim,
    'vin': v.vin,
    'license_plate': v.licensePlate,
    'fuel_type': v.fuelType?.wire,
    'engine_cc': v.engineCc,
    'power_hp': v.powerHp,
    'first_registration_date': v.firstRegistrationDate,
    'color': v.color,
    'photo_media_id': v.photoMediaId?.value,
    'tire_monthly_loss_bar': v.tireMonthlyLossBar,
    'updated_at': isoOrNull(v.updatedAt),
    'deleted_at': isoOrNull(v.deletedAt),
  },
);

final fuelEntryCodec = SyncCodec<FuelEntry>(
  resource: 'fuel_entries',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => e.vehicleId.value,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => FuelEntry(
    id: _id(m['id']),
    vehicleId: _id(m['vehicle_id']),
    createdByUserId: _idN(m['created_by_user_id']),
    date: parseDateOrNull(m['date']),
    odometer: (m['odometer'] as num?)?.toInt(),
    volumeLiters: doubleOrNull(m['volume_liters']),
    pricePerLiter: doubleOrNull(m['price_per_liter']),
    totalCost: doubleOrNull(m['total_cost']),
    fuelType: FuelType.fromWire(m['fuel_type'] as String?),
    station: m['station'] as String?,
    notes: m['notes'] as String?,
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'vehicle_id': e.vehicleId.value,
    'created_by_user_id': e.createdByUserId?.value,
    'date': e.date?.toUtc().toIso8601String(),
    'odometer': e.odometer,
    'volume_liters': e.volumeLiters,
    'price_per_liter': e.pricePerLiter,
    'total_cost': e.totalCost,
    'fuel_type': e.fuelType?.wire,
    'station': e.station,
    'notes': e.notes,
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);

final operationCodec = SyncCodec<Operation>(
  resource: 'maintenance_operations',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => e.vehicleId.value,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => Operation(
    id: _id(m['id']),
    vehicleId: _id(m['vehicle_id']),
    createdByUserId: _idN(m['created_by_user_id']),
    date: parseDate(m['date']),
    odometer: (m['odometer'] as num).toInt(),
    title: m['title'] as String?,
    provider: m['provider'] as String?,
    note: m['note'] as String?,
    isDiy: (m['is_diy'] as bool?) ?? false,
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'vehicle_id': e.vehicleId.value,
    'created_by_user_id': e.createdByUserId?.value,
    'date': e.date.toUtc().toIso8601String(),
    'odometer': e.odometer,
    'title': e.title,
    'provider': e.provider,
    'note': e.note,
    'is_diy': e.isDiy,
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);

// Lignes : scopées par operation_id (pas de vehicle_id → vehicleIdOf null,
// résolu via l'opération parente, comme les devis).
final operationLineCodec = SyncCodec<OperationLine>(
  resource: 'maintenance_operation_lines',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => null,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => OperationLine(
    id: _id(m['id']),
    operationId: _id(m['operation_id']),
    label: _strOr(m['label'], 'Poste'),
    partsCost: doubleOrNull(m['parts_cost']),
    laborCost: doubleOrNull(m['labor_cost']),
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'operation_id': e.operationId.value,
    'label': e.label,
    'parts_cost': e.partsCost,
    'labor_cost': e.laborCost,
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);

final planCodec = SyncCodec<Plan>(
  resource: 'maintenance_plans',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => e.vehicleId.value,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => Plan(
    id: _id(m['id']),
    vehicleId: _id(m['vehicle_id']),
    title: _strOr(m['title'], 'Échéance'),
    priority: TaskPriority.fromWire(m['priority'] as String?),
    estimatedCost: doubleOrNull(m['estimated_cost']),
    intervalKm: intOrNull(m['interval_km']),
    intervalMonths: intOrNull(m['interval_months']),
    dueDate: m['due_date'] as String?,
    dueOdometer: intOrNull(m['due_odometer']),
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'vehicle_id': e.vehicleId.value,
    'title': e.title,
    'priority': e.priority?.wire,
    'estimated_cost': e.estimatedCost,
    'interval_km': e.intervalKm,
    'interval_months': e.intervalMonths,
    'due_date': e.dueDate,
    'due_odometer': e.dueOdometer,
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);

// Devis : scopés par operation_id (pas de vehicle_id → vehicleIdOf null,
// le store les liste via listAll puis filtre par opération).
final maintenanceQuoteCodec = SyncCodec<MaintenanceQuote>(
  resource: 'maintenance_quotes',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => null,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => MaintenanceQuote(
    id: _id(m['id']),
    operationId: _id(m['operation_id']),
    // `source` : ancien nom de la colonne. Les lignes déjà en base locale le
    // portent encore tant qu'elles n'ont pas été réécrites — sans ce repli, le
    // prestataire d'un devis existant disparaîtrait à la mise à jour de l'app.
    provider: (m['provider'] ?? m['source']) as String?,
    amount: doubleOrNull(m['amount']),
    isSelected: (m['is_selected'] as bool?) ?? false,
    notes: m['notes'] as String?,
    // Repli sur `updated_at` pour les devis saisis avant que la date de
    // création ne soit conservée localement (l'ordre reste plausible).
    createdAt: parseDateOrNull(m['created_at']) ?? parseDate(m['updated_at']),
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'operation_id': e.operationId.value,
    'provider': e.provider,
    'amount': e.amount,
    'is_selected': e.isSelected,
    'notes': e.notes,
    // Seule ressource à pousser sa date de création : elle porte l'ordre des
    // devis d'une opération (le premier saisi fait référence par défaut).
    'created_at': isoOrNull(e.createdAt),
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);

final tirePressureCodec = SyncCodec<TirePressureEntry>(
  resource: 'tire_pressure_entries',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => e.vehicleId.value,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => TirePressureEntry(
    id: _id(m['id']),
    vehicleId: _id(m['vehicle_id']),
    createdByUserId: _idN(m['created_by_user_id']),
    date: parseDate(m['date']),
    odometer: (m['odometer'] as num).toInt(),
    pressures: (m['pressures'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
    targetPressureId: _idN(m['target_pressure_id']),
    notes: m['notes'] as String?,
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'vehicle_id': e.vehicleId.value,
    'created_by_user_id': e.createdByUserId?.value,
    'date': e.date.toUtc().toIso8601String(),
    'odometer': e.odometer,
    'pressures': e.pressures,
    'target_pressure_id': e.targetPressureId?.value,
    'notes': e.notes,
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);

final targetPressureCodec = SyncCodec<TargetPressure>(
  resource: 'vehicle_target_pressures',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => e.vehicleId.value,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => TargetPressure(
    id: _id(m['id']),
    vehicleId: _id(m['vehicle_id']),
    label: m['label'] as String,
    front: doubleOrNull(m['front']),
    rear: doubleOrNull(m['rear']),
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'vehicle_id': e.vehicleId.value,
    'label': e.label,
    'front': e.front,
    'rear': e.rear,
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);

// Inventaire de pneus : un pneu+jante physique. Position & km roulés dérivés du
// journal de montages (tire_mounts), pas stockés ici.
final tireCodec = SyncCodec<Tire>(
  resource: 'tires',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => e.vehicleId.value,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => Tire(
    id: _id(m['id']),
    vehicleId: _id(m['vehicle_id']),
    createdByUserId: _idN(m['created_by_user_id']),
    brand: m['brand'] as String?,
    model: m['model'] as String?,
    size: m['size'] as String?,
    marker: m['marker'] as String?,
    rimMaterial: RimMaterial.fromWire(m['rim_material'] as String?),
    rimSpec: m['rim_spec'] as String?,
    season: TireSeason.fromWire(m['season'] as String?),
    condition: TireCondition.fromWire(m['condition'] as String?),
    purchaseDate: m['purchase_date'] as String?,
    purchasePrice: doubleOrNull(m['purchase_price']),
    notes: m['notes'] as String?,
    disposedDate: m['disposed_date'] as String?,
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'vehicle_id': e.vehicleId.value,
    'created_by_user_id': e.createdByUserId?.value,
    'brand': e.brand,
    'model': e.model,
    'size': e.size,
    'marker': e.marker,
    'rim_material': e.rimMaterial?.wire,
    'rim_spec': e.rimSpec,
    'season': e.season?.wire,
    'condition': e.condition.wire,
    'purchase_date': e.purchaseDate,
    'purchase_price': e.purchasePrice,
    'notes': e.notes,
    'disposed_date': e.disposedDate,
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);

// Journal de montages : intervalle (position, km montage → km démontage) d'un
// pneu. Intervalle ouvert (dismounted_odometer null) = pneu monté actuellement.
final tireMountCodec = SyncCodec<TireMount>(
  resource: 'tire_mounts',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => e.vehicleId.value,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => TireMount(
    id: _id(m['id']),
    vehicleId: _id(m['vehicle_id']),
    tireId: _id(m['tire_id']),
    position: m['position'] as String,
    mountedOdometer: (m['mounted_odometer'] as num).toInt(),
    mountedDate: m['mounted_date'] as String?,
    dismountedOdometer: intOrNull(m['dismounted_odometer']),
    dismountedDate: m['dismounted_date'] as String?,
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'vehicle_id': e.vehicleId.value,
    'tire_id': e.tireId.value,
    'position': e.position,
    'mounted_odometer': e.mountedOdometer,
    'mounted_date': e.mountedDate,
    'dismounted_odometer': e.dismountedOdometer,
    'dismounted_date': e.dismountedDate,
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);

final costEntryCodec = SyncCodec<CostEntry>(
  resource: 'cost_entries',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => e.vehicleId.value,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => CostEntry(
    id: _id(m['id']),
    vehicleId: _id(m['vehicle_id']),
    createdByUserId: _idN(m['created_by_user_id']),
    label: m['label'] as String,
    category: m['category'] as String?,
    amount: doubleOrNull(m['amount']),
    date: parseDate(m['date']),
    notes: m['notes'] as String?,
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'vehicle_id': e.vehicleId.value,
    'created_by_user_id': e.createdByUserId?.value,
    'label': e.label,
    'category': e.category,
    'amount': e.amount,
    'date': e.date.toUtc().toIso8601String(),
    'notes': e.notes,
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);

// Médias : lecture seule en synchro (créés par upload REST), scopés par owner.
final mediaItemCodec = SyncCodec<MediaItem>(
  resource: 'media',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => null,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => MediaItem(
    id: _id(m['id']),
    ownerType: m['owner_type'] as String,
    ownerId: _id(m['owner_id']),
    kind: m['kind'] as String,
    category: m['category'] as String? ?? 'uncategorized',
    contentType: m['content_type'] as String?,
    originalFilename: m['original_filename'] as String?,
    fileSize: intOrNull(m['file_size']),
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'owner_type': e.ownerType,
    'owner_id': e.ownerId.value,
    'kind': e.kind,
    'category': e.category,
    'content_type': e.contentType,
    'original_filename': e.originalFilename,
    'file_size': e.fileSize,
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);

final ownershipCodec = SyncCodec<Ownership>(
  resource: 'vehicle_ownerships',
  idOf: (e) => e.id.value,
  vehicleIdOf: (e) => e.vehicleId.value,
  updatedAtOf: (e) => e.updatedAt,
  deletedAtOf: (e) => e.deletedAt,
  fromJson: (m) => Ownership(
    id: _id(m['id']),
    vehicleId: _id(m['vehicle_id']),
    userId: _idN(m['user_id']),
    firstName: m['first_name'] as String?,
    lastName: m['last_name'] as String?,
    acquiredDate: m['acquired_date'] as String?,
    acquiredOdometer: intOrNull(m['acquired_odometer']),
    purchasePrice: doubleOrNull(m['purchase_price']),
    isCurrent: (m['is_current'] as bool?) ?? false,
    updatedAt: parseDate(m['updated_at']),
    deletedAt: parseDateOrNull(m['deleted_at']),
  ),
  toJson: (e) => {
    'id': e.id.value,
    'vehicle_id': e.vehicleId.value,
    'user_id': e.userId?.value,
    'first_name': e.firstName,
    'last_name': e.lastName,
    'acquired_date': e.acquiredDate,
    'acquired_odometer': e.acquiredOdometer,
    'purchase_price': e.purchasePrice,
    'is_current': e.isCurrent,
    'updated_at': isoOrNull(e.updatedAt),
    'deleted_at': isoOrNull(e.deletedAt),
  },
);
