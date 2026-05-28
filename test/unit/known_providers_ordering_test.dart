import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';

/// Ordre des suggestions de prestataires (`rankProviders`) : par occurrences sur
/// les 10 dernières opérations, mais tous les prestataires connus restent proposés.
void main() {
  final vehicleId = UuidValue.generate();
  Operation op(String? provider, {required DateTime date}) => Operation(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        date: date,
        odometer: 100000,
        provider: provider,
        updatedAt: date,
      );

  test('classe par occurrences sur les 10 dernières opérations, propose quand même tout', () {
    final ops = <Operation>[
      // 11 vieilles opérations « Ancien » : le prestataire le plus fréquent au
      // total, mais entièrement hors de la fenêtre des 10 dernières opérations.
      for (var i = 0; i < 11; i++) op('Ancien', date: DateTime.utc(2025, 1, 1 + i)),
      // Les 10 opérations les plus récentes : Norauto ×6, Speedy ×3, Feu Vert ×1.
      for (var i = 0; i < 6; i++) op('Norauto', date: DateTime.utc(2026, 3, 1 + i)),
      for (var i = 0; i < 3; i++) op('Speedy', date: DateTime.utc(2026, 4, 1 + i)),
      op('Feu Vert', date: DateTime.utc(2026, 5, 1)),
    ];

    // Norauto(6) > Speedy(3) > Feu Vert(1) sur les 10 dernières ; « Ancien » (0
    // sur la fenêtre) reste proposé mais en dernier malgré sa fréquence globale.
    expect(rankProviders(ops), ['Norauto', 'Speedy', 'Feu Vert', 'Ancien']);
  });

  test('à récence égale, départage par fréquence globale puis alphabétique', () {
    final ops = <Operation>[
      // Fenêtre des 10 dernières : Norauto, Speedy et Avia y apparaissent une
      // fois chacun (égalité de récence), au milieu de 7 opérations sans prestataire.
      op('Speedy', date: DateTime.utc(2026, 5, 20)),
      op('Norauto', date: DateTime.utc(2026, 5, 19)),
      op('Avia', date: DateTime.utc(2026, 5, 18)),
      for (var i = 0; i < 7; i++) op(null, date: DateTime.utc(2026, 5, 1 + i)),
      // Hors fenêtre : Avia revient deux fois → plus fréquente au total.
      op('Avia', date: DateTime.utc(2025, 2, 1)),
      op('Avia', date: DateTime.utc(2025, 1, 1)),
    ];
    // Avia devant (total 3) ; Norauto/Speedy (total 1) départagés alphabétiquement.
    expect(rankProviders(ops), ['Avia', 'Norauto', 'Speedy']);
  });

  test('dédoublonne sans tenir compte de la casse, garde la 1ʳᵉ orthographe vue', () {
    expect(
      rankProviders([
        op('Norauto', date: DateTime.utc(2026, 1, 1)),
        op('norauto', date: DateTime.utc(2026, 1, 2)),
        op('NORAUTO', date: DateTime.utc(2026, 1, 3)),
      ]),
      ['Norauto'],
    );
  });

  test('ignore les opérations sans prestataire', () {
    expect(
      rankProviders([
        op(null, date: DateTime.utc(2026, 1, 2)),
        op('   ', date: DateTime.utc(2026, 1, 3)),
        op('Speedy', date: DateTime.utc(2026, 1, 1)),
      ]),
      ['Speedy'],
    );
  });
}
