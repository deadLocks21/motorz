import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/domain/model/fuel_entry.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';

/// Ordre des suggestions de stations (`rankStations`) : par occurrences sur les
/// 10 derniers pleins, mais toutes les stations connues restent proposées.
void main() {
  final vehicleId = UuidValue.generate();
  FuelEntry plein(String? station, {DateTime? date}) => FuelEntry(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        date: date,
        odometer: 100000,
        station: station,
        updatedAt: date ?? DateTime.utc(2026, 1, 1),
      );

  test('classe par occurrences sur les 10 derniers pleins, propose quand même tout', () {
    final entries = <FuelEntry>[
      // 11 vieux pleins « Ancienne » : la station la plus fréquente au total,
      // mais entièrement hors de la fenêtre des 10 derniers pleins.
      for (var i = 0; i < 11; i++) plein('Ancienne', date: DateTime.utc(2025, 1, 1 + i)),
      // Les 10 pleins les plus récents : Total ×6, Esso ×3, Avia ×1.
      for (var i = 0; i < 6; i++) plein('Total', date: DateTime.utc(2026, 3, 1 + i)),
      for (var i = 0; i < 3; i++) plein('Esso', date: DateTime.utc(2026, 4, 1 + i)),
      plein('Avia', date: DateTime.utc(2026, 5, 1)),
    ];

    // Total(6) > Esso(3) > Avia(1) sur les 10 derniers ; « Ancienne » (0 sur la
    // fenêtre) reste proposée mais en dernier malgré sa fréquence globale.
    expect(rankStations(entries), ['Total', 'Esso', 'Avia', 'Ancienne']);
  });

  test('départage à égalité sur les 10 derniers par fréquence globale puis alphabétique', () {
    final entries = <FuelEntry>[
      // Toutes apparaissent une fois dans les 10 derniers (égalité de récence).
      plein('Esso', date: DateTime.utc(2026, 5, 3)),
      plein('BP', date: DateTime.utc(2026, 5, 2)),
      plein('Avia', date: DateTime.utc(2026, 5, 1)),
      // BP a un plein de plus, plus ancien → plus fréquente au total.
      plein('BP', date: DateTime.utc(2025, 1, 1)),
    ];
    // BP (total 2) devant ; Avia/Esso (total 1) départagées alphabétiquement.
    expect(rankStations(entries), ['BP', 'Avia', 'Esso']);
  });

  test('dédoublonne sans tenir compte de la casse, garde la 1ʳᵉ orthographe vue', () {
    expect(
      rankStations([
        plein('Total', date: DateTime.utc(2026, 1, 1)),
        plein('total', date: DateTime.utc(2026, 1, 2)),
        plein('TOTAL', date: DateTime.utc(2026, 1, 3)),
      ]),
      ['Total'],
    );
  });

  test('ignore les pleins sans station', () {
    expect(
      rankStations([
        plein(null, date: DateTime.utc(2026, 1, 2)),
        plein('   ', date: DateTime.utc(2026, 1, 3)),
        plein('Esso', date: DateTime.utc(2026, 1, 1)),
      ]),
      ['Esso'],
    );
  });
}
