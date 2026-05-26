import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/due_status.service.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/maintenance_task.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

void main() {
  final vehicleId = UuidValue.generate();
  final now = DateTime(2026, 5, 26);

  MaintenanceTask periodic({int? lastDoneOdometer, int? intervalKm}) => MaintenanceTask(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        title: 'Vidange',
        kind: TaskKind.periodic,
        intervalKm: intervalKm,
        lastDoneOdometer: lastDoneOdometer,
        updatedAt: now,
      );

  test('périodique : à venir loin de l\'échéance', () {
    final task = periodic(lastDoneOdometer: 100000, intervalKm: 15000);
    final due = DueStatusService.compute(task, currentOdometer: 102000, now: now);
    expect(due.status, DueStatus.upcoming);
    expect(due.remainingKm, 13000);
  });

  test('périodique : bientôt dû sous le seuil de 1000 km', () {
    final task = periodic(lastDoneOdometer: 100000, intervalKm: 15000);
    final due = DueStatusService.compute(task, currentOdometer: 114500, now: now);
    expect(due.status, DueStatus.dueSoon);
    expect(due.remainingKm, 500);
  });

  test('périodique : en retard quand le km cible est dépassé', () {
    final task = periodic(lastDoneOdometer: 100000, intervalKm: 15000);
    final due = DueStatusService.compute(task, currentOdometer: 116000, now: now);
    expect(due.status, DueStatus.overdue);
    expect(due.remainingKm, -1000);
  });

  test('contrôle technique : échéance datée en retard', () {
    final task = MaintenanceTask(
      id: UuidValue.generate(),
      vehicleId: vehicleId,
      title: 'Contrôle technique',
      kind: TaskKind.controleTechnique,
      dueDate: '2026-05-01',
      updatedAt: now,
    );
    final due = DueStatusService.compute(task, now: now);
    expect(due.status, DueStatus.overdue);
    expect(due.remainingDays, isNegative);
  });
}
