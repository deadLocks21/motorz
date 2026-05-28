import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/domain/model/maintenance_catalog_item.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

void main() {
  final vehicleId = UuidValue.generate();
  final vidange = UuidValue.generate();
  final now = DateTime(2026, 5, 26);

  Operation makeOp(int odo, DateTime date, {DateTime? deletedAt}) => Operation(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        date: date,
        odometer: odo,
        updatedAt: date,
        deletedAt: deletedAt,
      );

  OperationLine catLine(Operation op, UuidValue catalogId) => OperationLine(
        id: UuidValue.generate(),
        operationId: op.id,
        catalogItemId: catalogId,
        updatedAt: op.date,
      );

  final vidangePlan = Plan(
    id: UuidValue.generate(),
    vehicleId: vehicleId,
    catalogItemId: vidange,
    intervalKm: 15000,
    updatedAt: now,
  );

  test('dernière réalisation = opération au km le plus élevé', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    final opB = makeOp(19000, DateTime(2025, 9, 12));
    final ld = MaintenanceDerivationService.lastDoneForPlan(
        vidangePlan, [opA, opB], [catLine(opA, vidange), catLine(opB, vidange)]);
    expect(ld!.odometer, 19000);
  });

  test('saisie rétroactive à km inférieur n\'écrase pas', () {
    final opB = makeOp(19000, DateTime(2025, 9, 12));
    // Saisie tardive (date récente) mais km bas → ne doit pas l\'emporter.
    final opLate = makeOp(1000, DateTime(2026, 1, 1));
    final ld = MaintenanceDerivationService.lastDoneForPlan(
        vidangePlan, [opB, opLate], [catLine(opB, vidange), catLine(opLate, vidange)]);
    expect(ld!.odometer, 19000);
  });

  test('opération supprimée → le compteur recule', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    final opB = makeOp(19000, DateTime(2025, 9, 12), deletedAt: now);
    final ld = MaintenanceDerivationService.lastDoneForPlan(
        vidangePlan, [opA, opB], [catLine(opA, vidange), catLine(opB, vidange)]);
    expect(ld!.odometer, 4200);
  });

  test('ligne supprimée → le compteur recule', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    final opB = makeOp(19000, DateTime(2025, 9, 12));
    final lB = catLine(opB, vidange).copyWith(deletedAt: now);
    final ld = MaintenanceDerivationService.lastDoneForPlan(
        vidangePlan, [opA, opB], [catLine(opA, vidange), lB]);
    expect(ld!.odometer, 4200);
  });

  test('ligne libre ne pilote aucun compteur', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    final free = OperationLine(
      id: UuidValue.generate(),
      operationId: opA.id,
      label: 'Réparation diverse',
      updatedAt: opA.date,
    );
    final ld = MaintenanceDerivationService.lastDoneForPlan(vidangePlan, [opA], [free]);
    expect(ld, isNull);
  });

  test('plan sans poste (à-venir) → pas de dérivation', () {
    final oneShot = Plan(
      id: UuidValue.generate(),
      vehicleId: vehicleId,
      title: 'Distribution',
      dueOdometer: 120000,
      updatedAt: now,
    );
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    expect(
      MaintenanceDerivationService.lastDoneForPlan(oneShot, [opA], [catLine(opA, vidange)]),
      isNull,
    );
  });

  test('titre dérivé des lignes', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    final catalog = {
      vidange.value: CatalogItem(id: vidange, userId: UuidValue.generate(), name: 'Vidange', updatedAt: now),
    };
    final free = OperationLine(
      id: UuidValue.generate(),
      operationId: opA.id,
      label: 'Géométrie',
      updatedAt: opA.date,
    );
    expect(MaintenanceDerivationService.deriveTitle([catLine(opA, vidange)], catalog), 'Vidange');
    expect(
      MaintenanceDerivationService.deriveTitle([catLine(opA, vidange), free], catalog),
      'Vidange + 1 autre',
    );
  });

  test('coût d\'opération = somme des lignes (null si rien)', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    final l1 = OperationLine(
        id: UuidValue.generate(), operationId: opA.id, catalogItemId: vidange, partsCost: 120, laborCost: 150, updatedAt: now);
    final l2 = OperationLine(
        id: UuidValue.generate(), operationId: opA.id, label: 'Géo', laborCost: 30, updatedAt: now);
    expect(MaintenanceDerivationService.operationCost([l1, l2]), 300);
    expect(MaintenanceDerivationService.operationCost(const []), isNull);
  });
}
