import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

void main() {
  final vehicleId = UuidValue.generate();
  final now = DateTime(2026, 5, 26);

  Operation makeOp(int odo, DateTime date, {DateTime? deletedAt}) => Operation(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        date: date,
        odometer: odo,
        updatedAt: date,
        deletedAt: deletedAt,
      );

  OperationLine makeLine(Operation op, String label, {DateTime? deletedAt}) => OperationLine(
        id: UuidValue.generate(),
        operationId: op.id,
        label: label,
        updatedAt: op.date,
        deletedAt: deletedAt,
      );

  final vidangePlan = Plan(
    id: UuidValue.generate(),
    vehicleId: vehicleId,
    title: 'Vidange',
    intervalKm: 15000,
    updatedAt: now,
  );

  test('dernière réalisation = opération au km le plus élevé (match par intitulé)', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    final opB = makeOp(19000, DateTime(2025, 9, 12));
    final ld = MaintenanceDerivationService.lastDoneForPlan(
        vidangePlan, [opA, opB], [makeLine(opA, 'Vidange'), makeLine(opB, 'vidange ')]);
    expect(ld!.odometer, 19000); // « vidange » (casse/espaces) matche aussi
  });

  test('saisie rétroactive à km inférieur n\'écrase pas', () {
    final opB = makeOp(19000, DateTime(2025, 9, 12));
    final opLate = makeOp(1000, DateTime(2026, 1, 1));
    final ld = MaintenanceDerivationService.lastDoneForPlan(
        vidangePlan, [opB, opLate], [makeLine(opB, 'Vidange'), makeLine(opLate, 'Vidange')]);
    expect(ld!.odometer, 19000);
  });

  test('opération supprimée → le compteur recule', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    final opB = makeOp(19000, DateTime(2025, 9, 12), deletedAt: now);
    final ld = MaintenanceDerivationService.lastDoneForPlan(
        vidangePlan, [opA, opB], [makeLine(opA, 'Vidange'), makeLine(opB, 'Vidange')]);
    expect(ld!.odometer, 4200);
  });

  test('ligne supprimée → le compteur recule', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    final opB = makeOp(19000, DateTime(2025, 9, 12));
    final ld = MaintenanceDerivationService.lastDoneForPlan(
        vidangePlan, [opA, opB], [makeLine(opA, 'Vidange'), makeLine(opB, 'Vidange', deletedAt: now)]);
    expect(ld!.odometer, 4200);
  });

  test('intitulé qui ne correspond pas → aucune réalisation', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    final ld = MaintenanceDerivationService.lastDoneForPlan(
        vidangePlan, [opA], [makeLine(opA, 'Plaquettes de frein')]);
    expect(ld, isNull);
  });

  test('titre dérivé des lignes', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    expect(MaintenanceDerivationService.deriveTitle([makeLine(opA, 'Vidange')]), 'Vidange');
    expect(
      MaintenanceDerivationService.deriveTitle([makeLine(opA, 'Vidange'), makeLine(opA, 'Géométrie')]),
      'Vidange + 1 autre',
    );
  });

  Plan oneShot(String title, DateTime createdAt) => Plan(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        title: title,
        updatedAt: createdAt,
      );

  test('ponctuelle faite : opération du même intitulé saisie après sa création', () {
    final plan = oneShot('Rétroviseur', DateTime(2026, 5, 1));
    final op = makeOp(13000, DateTime(2026, 5, 10)); // updatedAt = date > création
    expect(
      MaintenanceDerivationService.isOneShotDone(plan, [op], [makeLine(op, 'Rétroviseur')]),
      isTrue,
    );
  });

  test('ponctuelle pas faite : historique antérieur à sa création ne compte pas', () {
    final plan = oneShot('Rétroviseur', DateTime(2026, 5, 1));
    final old = makeOp(9000, DateTime(2025, 1, 1)); // updatedAt < création
    expect(
      MaintenanceDerivationService.isOneShotDone(plan, [old], [makeLine(old, 'Rétroviseur')]),
      isFalse,
    );
  });

  test('ponctuelle pas faite : aucune opération du même intitulé', () {
    final plan = oneShot('Rétroviseur', DateTime(2026, 5, 1));
    final op = makeOp(13000, DateTime(2026, 5, 10));
    expect(
      MaintenanceDerivationService.isOneShotDone(plan, [op], [makeLine(op, 'Vidange')]),
      isFalse,
    );
  });

  test('coût d\'opération = somme des lignes (null si rien)', () {
    final opA = makeOp(4200, DateTime(2024, 9, 12));
    final l1 = OperationLine(
        id: UuidValue.generate(), operationId: opA.id, label: 'Vidange', partsCost: 120, laborCost: 150, updatedAt: now);
    final l2 = OperationLine(
        id: UuidValue.generate(), operationId: opA.id, label: 'Géométrie', laborCost: 30, updatedAt: now);
    expect(MaintenanceDerivationService.operationCost([l1, l2]), 300);
    expect(MaintenanceDerivationService.operationCost(const []), isNull);
  });
}
