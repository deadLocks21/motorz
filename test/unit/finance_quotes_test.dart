import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/finance.service.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/maintenance_quote.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Estimatif « tout en garage » et économies, à partir des devis comparatifs
/// (§5.2 / §5.5) : un devis saisi compte toujours, celui qui fait référence est
/// le devis retenu (à défaut le premier saisi), et l'écart avec le coût réel
/// n'est une économie que sur une opération faite soi-même.
void main() {
  final vehicleId = UuidValue.generate();
  final at = DateTime.utc(2026, 3, 7);

  Operation operation(UuidValue id, {required bool isDiy}) => Operation(
        id: id,
        vehicleId: vehicleId,
        date: at,
        odometer: 11800,
        provider: isDiy ? null : 'Garage Dupont',
        isDiy: isDiy,
        updatedAt: at,
      );

  OperationLine line(UuidValue operationId, double cost) => OperationLine(
        id: UuidValue.generate(),
        operationId: operationId,
        label: 'Filtre à air',
        partsCost: cost,
        updatedAt: at,
      );

  MaintenanceQuote quote(
    UuidValue operationId,
    double amount, {
    bool isSelected = false,
    int dayOffset = 0,
    DateTime? deletedAt,
  }) =>
      MaintenanceQuote(
        id: UuidValue.generate(),
        operationId: operationId,
        provider: 'Garage',
        amount: amount,
        isSelected: isSelected,
        createdAt: at.add(Duration(days: dayOffset)),
        updatedAt: at,
        deletedAt: deletedAt,
      );

  TcoSummary compute(List<Operation> ops, List<OperationLine> lines, List<MaintenanceQuote> q) =>
      FinanceService.compute(
        ownerships: const [],
        fuel: const [],
        operations: ops,
        lines: lines,
        costs: const [],
        quotes: q,
        now: at,
      );

  test('sans devis, l\'estimatif se réduit au coût réel et rien n\'est comptabilisé', () {
    final id = UuidValue.generate();
    final tco = compute([operation(id, isDiy: true)], [line(id, 85)], const []);

    expect(tco.garageEstimate, 85);
    expect(tco.diySavings, 0);
    // À zéro, l'écran Finances masque le bloc : il ne dirait rien de neuf.
    expect(tco.quotedOperationCount, 0);
  });

  test('opération faite soi-même : l\'estimatif prend le devis, l\'écart est une économie', () {
    final id = UuidValue.generate();
    final tco = compute([operation(id, isDiy: true)], [line(id, 85)], [quote(id, 210)]);

    expect(tco.garageEstimate, 210);
    expect(tco.diySavings, 125);
    expect(tco.quotedOperationCount, 1);
    expect(tco.maintenanceCost, 85, reason: 'un devis n\'est jamais une dépense réelle');
  });

  test('opération confiée à un garage : le devis alimente l\'estimatif, pas les économies', () {
    final id = UuidValue.generate();
    final tco = compute([operation(id, isDiy: false)], [line(id, 300)], [quote(id, 350)]);

    expect(tco.garageEstimate, 350);
    expect(tco.diySavings, 0, reason: 'rien n\'a été évité : le garage a bien été payé');
  });

  test('plusieurs devis : le retenu fait référence, à défaut le premier saisi', () {
    final id = UuidValue.generate();
    final ops = [operation(id, isDiy: true)];
    final lines = [line(id, 85)];

    final retained = compute(ops, lines, [
      quote(id, 280, dayOffset: 0),
      quote(id, 210, dayOffset: 1, isSelected: true),
    ]);
    expect(retained.garageEstimate, 210);
    expect(retained.diySavings, 125);

    // Aucun retenu (données antérieures au marquage) : le premier saisi prend le relais.
    final none = compute(ops, lines, [
      quote(id, 280, dayOffset: 0),
      quote(id, 210, dayOffset: 1),
    ]);
    expect(none.garageEstimate, 280);
  });

  test('un devis supprimé ne fait plus référence', () {
    final id = UuidValue.generate();
    final tco = compute([operation(id, isDiy: true)], [line(id, 85)], [
      quote(id, 280, isSelected: true, deletedAt: at),
      quote(id, 210, dayOffset: 1),
    ]);

    expect(tco.garageEstimate, 210);
  });

  test('un devis sans montant laisse l\'opération à son coût réel', () {
    final id = UuidValue.generate();
    final tco = compute([operation(id, isDiy: true)], [line(id, 85)], [
      MaintenanceQuote(
        id: UuidValue.generate(),
        operationId: id,
        provider: 'Garage',
        createdAt: at,
        updatedAt: at,
      ),
    ]);

    expect(tco.garageEstimate, 85);
    expect(tco.quotedOperationCount, 0);
  });

  test('économies et estimatif s\'agrègent sur tout le parc d\'opérations', () {
    final diy = UuidValue.generate();
    final garage = UuidValue.generate();
    final sansDevis = UuidValue.generate();
    final tco = compute(
      [
        operation(diy, isDiy: true),
        operation(garage, isDiy: false),
        operation(sansDevis, isDiy: true),
      ],
      [line(diy, 85), line(garage, 300), line(sansDevis, 40)],
      [quote(diy, 210), quote(garage, 350)],
    );

    expect(tco.garageEstimate, 210 + 350 + 40);
    expect(tco.diySavings, 125);
    expect(tco.quotedOperationCount, 2);
  });
}
