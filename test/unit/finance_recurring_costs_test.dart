import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/finance.service.dart';
import 'package:motorz/core/domain/model/cost_entry.dart';
import 'package:motorz/core/domain/model/enums.dart';
import 'package:motorz/core/domain/model/ownership.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Frais récurrents et place du prix d'achat (§5.2) : une charge perpétuelle se
/// décrit une fois (montant + périodicité) et s'étale au prorata du temps de
/// possession ; le prix d'achat alimente le coût total mais reste hors des
/// ratios €/mois et €/km.
void main() {
  final vehicleId = UuidValue.generate();
  final now = DateTime.utc(2026, 7, 1);

  Ownership mine({String date = '2025-07-01', double? price, int? odometer}) => Ownership(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        acquiredDate: date,
        acquiredOdometer: odometer,
        purchasePrice: price,
        isCurrent: true,
        updatedAt: now,
      );

  CostEntry cost({
    required double amount,
    CostRecurrence recurrence = CostRecurrence.annuel,
    required DateTime date,
    DateTime? endDate,
  }) =>
      CostEntry(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        label: 'Assurance',
        category: 'assurance',
        amount: amount,
        recurrence: recurrence,
        date: date,
        endDate: endDate,
        updatedAt: now,
      );

  TcoSummary compute({List<Ownership> ownerships = const [], List<CostEntry> costs = const [], int? odometer}) =>
      FinanceService.compute(
        ownerships: ownerships,
        fuel: const [],
        operations: const [],
        lines: const [],
        costs: costs,
        currentOdometer: odometer,
        now: now,
      );

  group('étalement d\'une charge récurrente', () {
    test('une prime annuelle compte au prorata des mois écoulés', () {
      // Souscrite le jour de l'achat, un an plus tôt : une année pleine courue.
      final tco = compute(
        ownerships: [mine()],
        costs: [cost(amount: 1200, date: DateTime.utc(2025, 7, 1))],
      );

      expect(tco.otherCost, closeTo(1200, 5));
      expect(tco.recurringMonthly, closeTo(100, 0.01));
    });

    test('la fenêtre démarre à mon acquisition, pas à la souscription', () {
      // Contrat ouvert deux ans avant que le véhicule soit à moi : seuls les
      // 12 mois de ma possession me sont imputables.
      final tco = compute(
        ownerships: [mine()],
        costs: [cost(amount: 1200, date: DateTime.utc(2023, 7, 1))],
      );

      expect(tco.otherCost, closeTo(1200, 5));
    });

    test('la fenêtre s\'arrête à la résiliation', () {
      // Six mois courus puis résiliation : la moitié d'une prime annuelle.
      final tco = compute(
        ownerships: [mine()],
        costs: [
          cost(
            amount: 1200,
            date: DateTime.utc(2025, 7, 1),
            endDate: DateTime.utc(2026, 1, 1),
          ),
        ],
      );

      expect(tco.otherCost, closeTo(600, 5));
      expect(tco.recurringMonthly, 0, reason: 'le contrat ne court plus aujourd\'hui');
    });

    test('on ne compte que le couru, jamais le prévisionnel', () {
      // Charge démarrée il y a six mois : rien du semestre à venir n'est compté.
      // Le calcul raisonne en mois glissants de 30,44 jours, et ce semestre-ci
      // n'en compte que 181 — d'où les ~595 € plutôt que 600 pile.
      final tco = compute(
        ownerships: [mine()],
        costs: [cost(amount: 1200, date: DateTime.utc(2026, 1, 1))],
      );

      expect(tco.otherCost, closeTo(600, 10));
    });

    test('une charge future ou une fenêtre inversée valent zéro', () {
      // Ni l\'API REST ni la synchro ne rejettent une fin antérieure au début :
      // c\'est le calcul qui borne, sous peine de coût négatif.
      final future = compute(
        ownerships: [mine()],
        costs: [cost(amount: 1200, date: DateTime.utc(2027, 1, 1))],
      );
      expect(future.otherCost, 0);

      final inverted = compute(
        ownerships: [mine()],
        costs: [
          cost(
            amount: 1200,
            date: DateTime.utc(2026, 1, 1),
            endDate: DateTime.utc(2025, 1, 1),
          ),
        ],
      );
      expect(inverted.otherCost, 0);
    });

    test('chaque périodicité se ramène au même mensuel', () {
      for (final (recurrence, amount) in [
        (CostRecurrence.mensuel, 100.0),
        (CostRecurrence.trimestriel, 300.0),
        (CostRecurrence.semestriel, 600.0),
        (CostRecurrence.annuel, 1200.0),
      ]) {
        final tco = compute(
          ownerships: [mine()],
          costs: [cost(amount: amount, recurrence: recurrence, date: DateTime.utc(2025, 7, 1))],
        );
        expect(tco.recurringMonthly, closeTo(100, 0.01), reason: recurrence.label);
        expect(tco.otherCost, closeTo(1200, 5), reason: recurrence.label);
      }
    });

    test('un frais ponctuel garde son montant et ne pèse pas sur la charge fixe', () {
      final tco = compute(
        ownerships: [mine()],
        costs: [
          cost(
            amount: 350,
            recurrence: CostRecurrence.ponctuel,
            date: DateTime.utc(2026, 2, 1),
          ),
        ],
      );

      expect(tco.otherCost, 350);
      expect(tco.recurringMonthly, 0);
    });

    test('un frais ponctuel antérieur à mon achat reste hors de mon coût', () {
      final tco = compute(
        ownerships: [mine()],
        costs: [
          cost(
            amount: 350,
            recurrence: CostRecurrence.ponctuel,
            date: DateTime.utc(2024, 2, 1),
          ),
        ],
      );

      expect(tco.otherCost, 0);
    });
  });

  group('place du prix d\'achat', () {
    test('il alimente le coût total mais pas le coût d\'usage', () {
      final tco = compute(
        ownerships: [mine(price: 18000)],
        costs: [cost(amount: 1200, date: DateTime.utc(2025, 7, 1))],
      );

      expect(tco.usageCost, closeTo(1200, 5));
      expect(tco.tco, closeTo(19200, 5));
      expect(tco.purchasePrice, 18000);
    });

    test('les ratios €/mois et €/km ignorent le prix d\'achat', () {
      final tco = compute(
        ownerships: [mine(price: 18000, odometer: 10000)],
        costs: [cost(amount: 1200, date: DateTime.utc(2025, 7, 1))],
        odometer: 22000,
      );

      // 1200 € d'usage sur 12 mois et 12 000 km — l'achat n'entre nulle part.
      expect(tco.monthlyCost, closeTo(100, 1));
      expect(tco.costPerKm, closeTo(0.1, 0.001));
    });
  });
}
