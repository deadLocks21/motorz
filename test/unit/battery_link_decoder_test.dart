import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/battery_report.service.dart';

/// Lien réel d'un testeur OWIM (cf. §15.4 du brief). Le rapport tient
/// entièrement dans le paramètre `d` : la page qui l'affiche ne fait qu'un
/// décodage local.
const _link = 'https://e.dh5z.com/?d=10760127308670110010000337200000000000000000000000041';

void main() {
  group('lien de testeur de batterie', () {
    test('décode le rapport réel, champ par champ', () {
      final report = BatteryLinkDecoder.decode(_link)!;
      expect(report.result, 'Bonne batterie');
      expect(report.measurements, {
        'battery_type': 'Normal',
        'rated': 760,
        'voltage': 12.73,
        'measured': 867,
        'standard': 'CCA',
        'result': 'Bonne batterie',
        'soc': 100,
        'soh': 100,
        'internal_mohm': 3.37,
        'vehicle_type': 'Voiture',
      });
    });

    test('les tests de démarreur et de charge non effectués ne sont pas inventés', () {
      final m = BatteryLinkDecoder.decode(_link)!.measurements;
      // Tous les champs correspondants sont à zéro dans ce rapport : on ne
      // stocke pas « 0,00 V au démarrage », qui se lirait comme une mesure.
      expect(m.containsKey('cranking_voltage'), isFalse);
      expect(m.containsKey('charging_loaded_voltage'), isFalse);
      expect(m.containsKey('ripple'), isFalse);
    });

    test('reconnaît un lien décodable', () {
      expect(BatteryLinkDecoder.canDecode(_link), isTrue);
    });

    test('un rapport avec test de démarreur et de charge est décodé entièrement', () {
      // Même préfixe, mais les blocs démarreur (10,42 V / 980 ms / normal) et
      // charge (14,10 V en charge, 14,40 V hors charge, ripple 12, normal) sont
      // renseignés.
      const d = '107601273086701100100003372' // positions 0-26, comme ci-dessus
          '1042' // cranking voltage
          '0980' // durée
          '1' // verdict démarreur
          '00' // positions 36-37, non lues
          '1410' // tension avec charge
          '1440' // tension sans charge
          '0012' // ripple
          '1' // verdict de charge
          '41';
      final m = BatteryLinkDecoder.decode('https://e.dh5z.com/?d=$d')!.measurements;
      expect(m['cranking_voltage'], 10.42);
      expect(m['cranking_ms'], 980);
      expect(m['cranking_result'], 'Normal');
      expect(m['charging_loaded_voltage'], 14.10);
      expect(m['charging_unloaded_voltage'], 14.40);
      expect(m['ripple'], 12);
      expect(m['charging_result'], 'Normal');
    });

    test('verdicts dégradés', () {
      String withResult(String r) =>
          'https://e.dh5z.com/?d=10760127308670${r}09000850033720000000000000000000000041';
      expect(BatteryLinkDecoder.decode(withResult('2'))!.result, 'À remplacer');
      expect(BatteryLinkDecoder.decode(withResult('5'))!.result, 'Mauvaise cellule');
    });

    test('lien d\'un format inconnu : rien n\'est décodé (le lien reste un lien)', () {
      expect(BatteryLinkDecoder.decode('https://exemple.fr/rapport/42'), isNull);
      expect(BatteryLinkDecoder.decode('https://e.dh5z.com/?d=abc'), isNull);
      // Trop court pour être un rapport : on ne devine pas.
      expect(BatteryLinkDecoder.decode('https://e.dh5z.com/?d=1076'), isNull);
      expect(BatteryLinkDecoder.canDecode('pas une url'), isFalse);
    });

    test('rapport tronqué : on décode ce qui est lisible, sans extrapoler', () {
      // 27 caractères = jusqu'au type de véhicule inclus.
      final m = BatteryLinkDecoder.decode('https://e.dh5z.com/?d=107601273086701100100003372')!
          .measurements;
      expect(m['voltage'], 12.73);
      expect(m.containsKey('cranking_voltage'), isFalse);
    });
  });
}
