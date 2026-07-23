import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/diagnostic_report.service.dart';
import 'package:motorz/core/domain/model/diagnostic_code.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

/// Rapport réel exporté par Car Scanner ELM OBD2 (extrait fidèle, avec ses
/// bizarreries : nom de calculateur doublé, profil de connexion collé à la date).
const _carScannerReport = '''
Car Scanner ELM OBD2
Version: 1.118.0/401180/GP
DTC report
Connection profile: Citroen OBD-II / EOBDDate: 28/05/2025 20:20:20
============================
OBD-IIOBD-II
DTCs: 3
----------------------------
P2291 [0x2291]
Injector control pressure, engine cranking - pressure too low
Statut: En attente de défaut présent
----------------------------
P0017 [0x0017]
Crankshaft position/camshaft position, bank 1 sensor B - correlation
Statut: En attente de défaut présent
----------------------------
P050B [0x050B]
Ignition timing, cold start - performance problem
Statut: En attente de défaut présent
============================
Unité de contrôle moteur#1Unité de contrôle moteur#1
DTCs: 3
----------------------------
P2291 [0x2291]
Injector control pressure, engine cranking - pressure too low
Statut: En attente de défaut présent
----------------------------
P0017 [0x0017]
Crankshaft position/camshaft position, bank 1 sensor B - correlation
Statut: En attente de défaut présent
----------------------------
P050B [0x050B]
Ignition timing, cold start - performance problem
Statut: En attente de défaut présent
============================
Unité de commande de transmission#1
Aucun code défaut détecté.
============================
Power steering
Aucun code défaut détecté.
============================
ABS
Aucun code défaut détecté.
''';

void main() {
  group('rapport Car Scanner', () {
    final report = DiagnosticReportParser.parse(_carScannerReport);

    test('en-tête : outil, profil de connexion et date', () {
      expect(report.tool, 'Car Scanner ELM OBD2 1.118.0');
      // Le profil et la date arrivent collés sur la même ligne.
      expect(report.connectionProfile, 'Citroen OBD-II / EOBD');
      expect(report.date, DateTime(2025, 5, 28, 20, 20, 20));
      expect(report.usedFallback, isFalse);
    });

    test('les calculateurs sans défaut sont retenus eux aussi', () {
      // C'est ce qui permettra de distinguer « disparu » de « non revérifié ».
      expect(
        report.modules,
        containsAll(['Unité de commande de transmission#1', 'Power steering', 'ABS']),
      );
    });

    test('le nom de calculateur doublé par l\'export est réduit', () {
      expect(report.modules, contains('OBD-II'));
      expect(report.modules, contains('Unité de contrôle moteur#1'));
      expect(report.modules.any((m) => m.contains('OBD-IIOBD-II')), isFalse);
    });

    test('3 défauts distincts, remontés par 2 calculateurs = 6 lignes', () {
      expect(report.distinctCodes, ['P2291', 'P0017', 'P050B']);
      expect(report.codes, hasLength(6));
      expect(report.codes.where((c) => c.code == 'P2291').map((c) => c.module).toList(),
          ['OBD-II', 'Unité de contrôle moteur#1']);
    });

    test('description et statut d\'un code', () {
      final code = report.codes.firstWhere((c) => c.code == 'P0017');
      expect(code.description,
          'Crankshaft position/camshaft position, bank 1 sensor B - correlation');
      expect(code.rawStatus, 'En attente de défaut présent');
      // « En attente de défaut *présent* » reste un code en attente : chercher
      // « présent » d'abord le classerait à tort en confirmé.
      expect(code.status, DiagnosticCodeStatus.pending);
    });

    test('la ligne « DTCs: 3 » n\'est pas prise pour une description', () {
      expect(report.codes.every((c) => c.description?.startsWith('DTCs') != true), isTrue);
    });
  });

  group('repli générique', () {
    test('format inconnu : les codes sont quand même reconnus, sans module', () {
      final report = DiagnosticReportParser.parse(
        'Diag du 12 juin: defauts P0301 et U0100 releves, voir garage.',
      );
      expect(report.usedFallback, isTrue);
      expect(report.distinctCodes, ['P0301', 'U0100']);
      expect(report.codes.every((c) => c.module == null), isTrue);
      expect(report.modules, isEmpty);
    });

    test('doublons écartés dans le repli', () {
      final report = DiagnosticReportParser.parse('P0017 ... P0017 ... P0017');
      expect(report.codes, hasLength(1));
    });

    test('texte sans aucun code : rapport vide, pas d\'invention', () {
      final report = DiagnosticReportParser.parse('Rien à signaler sur ce vehicule.');
      expect(report.isEmpty, isTrue);
    });

    test('texte vide', () {
      expect(DiagnosticReportParser.parse('   ').isEmpty, isTrue);
    });
  });

  group('statuts', () {
    test('normalisation multilingue', () {
      expect(DiagnosticReportParser.normalizeStatus('En attente de défaut présent'),
          DiagnosticCodeStatus.pending);
      expect(DiagnosticReportParser.normalizeStatus('Pending'), DiagnosticCodeStatus.pending);
      expect(DiagnosticReportParser.normalizeStatus('Défaut présent'),
          DiagnosticCodeStatus.confirmed);
      expect(DiagnosticReportParser.normalizeStatus('Stored'), DiagnosticCodeStatus.confirmed);
      expect(DiagnosticReportParser.normalizeStatus('Permanent'), DiagnosticCodeStatus.permanent);
      expect(DiagnosticReportParser.normalizeStatus(null), DiagnosticCodeStatus.unknown);
      expect(DiagnosticReportParser.normalizeStatus('???'), DiagnosticCodeStatus.unknown);
    });
  });

  group('code défaut', () {
    test('normalisation et forme hexadécimale dérivée', () {
      expect(DiagnosticCode.normalizeCode(' p2291 '), 'P2291');
      expect(DiagnosticCode.normalizeCode('P-2291'), 'P2291');

      final code = DiagnosticCode(
        id: UuidValue.generate(),
        sessionId: UuidValue.generate(),
        code: 'P2291',
        updatedAt: DateTime(2025),
      );
      // La forme hexa affichée par les outils est une réécriture du code, pas
      // une donnée à stocker.
      expect(code.hex, '0x2291');
      expect(code.domainLabel, 'Moteur / transmission');
    });
  });
}
