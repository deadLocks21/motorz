import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/due_status.service.dart';
import 'package:motorz/core/application/services/maintenance_derivation.service.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

void main() {
  final vehicleId = UuidValue.generate();
  final now = DateTime(2026, 5, 26);

  Plan recurring({int? intervalKm, int? intervalMonths}) => Plan(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        title: 'Vidange',
        intervalKm: intervalKm,
        intervalMonths: intervalMonths,
        updatedAt: now,
      );

  test('récurrent : à venir loin de l\'échéance', () {
    final plan = recurring(intervalKm: 15000);
    final due = DueStatusService.compute(plan,
        lastDone: LastDone(odometer: 100000, date: now), currentOdometer: 102000, now: now);
    expect(due.status, DueStatus.upcoming);
    expect(due.remainingKm, 13000);
  });

  test('récurrent : bientôt dû sous le seuil de 1000 km', () {
    final plan = recurring(intervalKm: 15000);
    final due = DueStatusService.compute(plan,
        lastDone: LastDone(odometer: 100000, date: now), currentOdometer: 114500, now: now);
    expect(due.status, DueStatus.dueSoon);
    expect(due.remainingKm, 500);
  });

  test('récurrent : en retard quand le km cible est dépassé', () {
    final plan = recurring(intervalKm: 15000);
    final due = DueStatusService.compute(plan,
        lastDone: LastDone(odometer: 100000, date: now), currentOdometer: 116000, now: now);
    expect(due.status, DueStatus.overdue);
    expect(due.remainingKm, -1000);
  });

  test('échéance datée (amorce) en retard, sans dernière réalisation', () {
    final plan = Plan(
      id: UuidValue.generate(),
      vehicleId: vehicleId,
      title: 'Contrôle technique',
      intervalMonths: 24,
      dueDate: '2026-05-01',
      updatedAt: now,
    );
    final due = DueStatusService.compute(plan, now: now); // pas de lastDone → amorce
    expect(due.status, DueStatus.overdue);
    expect(due.remainingDays, isNegative);
  });

  test('l\'intervalle prend le relais de l\'amorce une fois une réalisation connue', () {
    final plan = Plan(
      id: UuidValue.generate(),
      vehicleId: vehicleId,
      title: 'Contrôle technique',
      intervalMonths: 24,
      dueDate: '2026-05-01', // amorce passée
      updatedAt: now,
    );
    final due = DueStatusService.compute(plan,
        lastDone: LastDone(odometer: 50000, date: DateTime(2026, 4, 1)), now: now);
    expect(due.dueDate, DateTime(2028, 4, 1));
    expect(due.status, DueStatus.upcoming);
  });

  test('ponctuel (sans intervalle) : utilise la cible km', () {
    final plan = Plan(
      id: UuidValue.generate(),
      vehicleId: vehicleId,
      title: 'Distribution',
      dueOdometer: 120000,
      updatedAt: now,
    );
    final due = DueStatusService.compute(plan, currentOdometer: 119500, now: now);
    expect(due.remainingKm, 500);
    expect(due.status, DueStatus.dueSoon);
  });
}
