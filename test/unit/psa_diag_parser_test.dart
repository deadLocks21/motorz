import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/diagnostic_report.service.dart';
import 'package:motorz/core/domain/model/diagnostic_code.dart';

/// Texte réel extrait d'un rapport « Défauts Expert » PSA-DIAG (Peugeot Expert 3),
/// tel que l'API le renvoie après extraction du PDF — mise en page multi-colonnes
/// aplatie, avec ses entrelacements. Sert de garde-fou : c'est *ce* format que
/// l'utilisateur produit.
const _psaReport =
    r'''Utilisateur : Véhicule : EXPERT/EXPERT 3 VIN : VF3XDRHH8BZ000000 Date impression : dimanche 22 mars 2026 15:07:48 Début de session véhicule : Version de l'outil : 09.180_PSA-DIAG Test global Expert/Test global Vehicle\menu_tgref.s : 81_02 FAMILLE N° CALCULATEUR 3 Boîtier de servitude intelligent BSI (3 Défauts) Calculateur contrôle moteur DCM3.5 Antiblocage de roue (ABS) ou contrôle dynamique de stabilité (ESP) ESP81 Direction assistée GEP 2 Chauffage additionnel CHAUFF_ADD (2 Défauts) F40A Défaut de la jauge à huile. A4C9 Défaut d'éclairage du feu de brouillard arrière droit. F5FF Défaut réinitialisation inattendue du Boîtier de Servitude Intelligent. Propriétés Origine Local Caractérisation du défaut Non caractérisé Propriétés Origine Local Caractérisation du défaut Court-circuit au plus Propriétés Origine Local Caractérisation du défaut Non caractérisé Veuillez patienter pendant que l'application génère le document d'impression 1 of 4 22/03/2026 15:08 260B Défaut sur le circuit électrique de la pompe à eau 2001 Défaut interne du réchauffeur Propriétés Origine Local Statut Fugitif Caractérisation du défaut CC- Liste des variables associées Température d'eau 76 °C Tension d'alimentation 13.6 Volt(s) Mode de fonctionnement de la chaudière En fonctionnement en mode additionnel Présence de flamme Non détectée Commande pompe doseuse de carburant Inactivé Commande pompe à eau ( selon véhicule ) Active Doigt d'incandescence Active Commande turbine à air de combustion Active Propriétés Origine Local Statut Fugitif Caractérisation du défaut Non caractérisé Liste des variables associées Température d'eau 214 °C Tension d'alimentation 13.9 Volt(s) Mode de fonctionnement de la chaudière En fonctionnement en mode additionnel Présence de flamme Non détectée 2 of 4 22/03/2026 15:08 Boîtier de servitude remorque BSR Boîtier de transformation carrosserie Calculateur inconnu Attention, calculateur présent sur véhicule mais télécodé absent Boîtier de servitude moteur BSM Calculateur de coussins gonflables et prétensionneurs SAC_AUTOLIV Combiné COMBINE Aide au stationnement AAS Commandes sous volant de direction HDC Climatisation CLIM_REGULEE Boîtier télématique (RTx) ou radionavigation RADIONAV_RNEG Tableau de climatisation arrière TAB_CLIM_AR Capteur de pluie et de luminosité PLUIE_LUMINOSITE Détection de sous-gonflage Non présent Suspension pneumatique Non présent 3 of 4 22/03/2026 15:08 4 of 4 22/03/2026 15:08''';

void main() {
  group('rapport PSA-DIAG « Défauts Expert »', () {
    final report = DiagnosticReportParser.parse(_psaReport);

    test('reconnu comme format connu, pas via le repli générique', () {
      expect(PsaDiagParser.matches(_psaReport), isTrue);
      expect(report.usedFallback, isFalse);
    });

    test('en-tête : outil et date', () {
      expect(report.tool, 'PSA-DIAG 09.180');
      expect(report.date, DateTime(2026, 3, 22, 15, 8));
    });

    test('5 défauts (là où le parser SAE n\'en voyait aucun)', () {
      // Les codes PSA sont des hexa constructeur sans préfixe P/B/C/U.
      expect(report.distinctCodes, ['F40A', 'A4C9', 'F5FF', '260B', '2001']);
      expect(report.codes, hasLength(5));
    });

    test('les deux calculateurs en défaut sont identifiés', () {
      expect(report.modules, ['BSI', 'CHAUFF_ADD']);
    });

    test('chaque code est rattaché à son calculateur par le compteur « (N Défauts) »', () {
      // BSI annonce 3 défauts, CHAUFF_ADD en annonce 2 : la somme (5) partitionne.
      expect(report.codes.where((c) => c.module == 'BSI').map((c) => c.code).toList(),
          ['F40A', 'A4C9', 'F5FF']);
      expect(report.codes.where((c) => c.module == 'CHAUFF_ADD').map((c) => c.code).toList(),
          ['260B', '2001']);
    });

    test('description en clair, caractérisation ajoutée quand elle informe', () {
      final f40a = report.codes.firstWhere((c) => c.code == 'F40A');
      expect(f40a.description, 'Défaut de la jauge à huile');

      // A4C9 est caractérisé « Court-circuit au plus » : on l'accole.
      final a4c9 = report.codes.firstWhere((c) => c.code == 'A4C9');
      expect(a4c9.description,
          'Défaut d\'éclairage du feu de brouillard arrière droit — Court-circuit au plus');

      // « Non caractérisé » n'apporte rien : la description reste nue.
      final f5ff = report.codes.firstWhere((c) => c.code == 'F5FF');
      expect(f5ff.description, isNot(contains('—')));
    });

    test('statut : présent par défaut, en attente si « Fugitif »', () {
      // BSI : défauts présents (aucune mention de statut dans le bloc).
      final f40a = report.codes.firstWhere((c) => c.code == 'F40A');
      expect(f40a.status, DiagnosticCodeStatus.confirmed);
      expect(f40a.rawStatus, 'Présent');

      // Chauffage additionnel : défauts fugitifs (intermittents).
      final b260 = report.codes.firstWhere((c) => c.code == '260B');
      expect(b260.status, DiagnosticCodeStatus.pending);
      expect(b260.rawStatus, 'Fugitif');
      expect(b260.description, contains('CC-'));
    });

    test('ni le VIN ni les années de date ne sont pris pour des codes', () {
      // Le VIN contient des suites hexa (« 0000 ») et « 2026 » est une année :
      // aucun ne doit ressortir comme code (fragments protégés par les bornes).
      expect(report.distinctCodes, isNot(contains('0000')));
      expect(report.distinctCodes, isNot(contains('2026')));
    });
  });

  group('robustesse PSA', () {
    test('compteurs incohérents : les codes restent, les modules non devinés', () {
      // « (9 Défauts) » ne colle pas aux 2 codes présents → pas de partition,
      // mais les codes et descriptions sont conservés (justesse > richesse).
      const text = 'Version de l\'outil : 09.180_PSA-DIAG '
          'Bidule BIDULE (9 Défauts) '
          'F40A Défaut de la jauge à huile. 260B Défaut pompe à eau. '
          '22/03/2026 15:08';
      final report = DiagnosticReportParser.parse(text);
      expect(report.distinctCodes, ['F40A', '260B']);
      expect(report.codes.every((c) => c.module == null), isTrue);
    });

    test('sans bloc de propriétés, le statut reste inconnu plutôt que deviné', () {
      const text = 'Version de l\'outil : 09.180_PSA-DIAG '
          'Bidule BIDULE (1 Défauts) F40A Défaut de la jauge à huile. 22/03/2026 15:08';
      final report = DiagnosticReportParser.parse(text);
      expect(report.codes.single.status, DiagnosticCodeStatus.unknown);
      expect(report.codes.single.module, 'BIDULE');
    });
  });
}
