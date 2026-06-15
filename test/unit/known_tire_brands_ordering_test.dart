import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/domain/model/tire.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/ui/providers/vehicle_data_providers.dart';

/// Ordre des suggestions marque/taille de pneu : par fréquence globale puis
/// alphabétique, dédoublonnage insensible à la casse.
void main() {
  final vehicleId = UuidValue.generate();
  Tire t({String? brand, String? size}) => Tire(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        brand: brand,
        size: size,
        updatedAt: DateTime.utc(2026, 1, 1),
      );

  group('rankTireBrands', () {
    test('par fréquence décroissante', () {
      final tires = [
        t(brand: 'Michelin'),
        t(brand: 'Michelin'),
        t(brand: 'Michelin'),
        t(brand: 'Continental'),
        t(brand: 'Continental'),
        t(brand: 'Bridgestone'),
      ];
      expect(rankTireBrands(tires), ['Michelin', 'Continental', 'Bridgestone']);
    });

    test('égalité départagée alphabétiquement', () {
      expect(rankTireBrands([t(brand: 'Pirelli'), t(brand: 'Goodyear')]), ['Goodyear', 'Pirelli']);
    });

    test('dédoublonne insensible à la casse, garde la 1ʳᵉ orthographe', () {
      expect(
        rankTireBrands([t(brand: 'Michelin'), t(brand: 'michelin'), t(brand: 'MICHELIN')]),
        ['Michelin'],
      );
    });

    test('ignore les marques vides/nulles', () {
      expect(rankTireBrands([t(brand: null), t(brand: '   '), t(brand: 'Michelin')]), ['Michelin']);
    });
  });

  group('rankTireSizes', () {
    test('par fréquence puis alphabétique', () {
      expect(
        rankTireSizes([t(size: '255/40 R19'), t(size: '255/40 R19'), t(size: '205/55 R16')]),
        ['255/40 R19', '205/55 R16'],
      );
    });
  });
}
