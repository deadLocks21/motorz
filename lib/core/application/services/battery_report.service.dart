/// Rapport d'un testeur de batterie décodé depuis son lien.
class BatteryReport {
  /// Verdict lisible (« Bonne batterie »).
  final String? result;

  /// Mesures prêtes à stocker dans `DiagnosticSession.measurements`.
  final Map<String, dynamic> measurements;

  const BatteryReport({this.result, required this.measurements});
}

/// Décodage des liens de rapport de testeur de batterie (§15.4).
///
/// Ces liens **portent la donnée dans leur paramètre** : la page qui les
/// affiche ne fait qu'un décodage local, sans jamais interroger de serveur. On
/// fait donc pareil — hors-ligne, sans appeler le site, et ce qu'on en tire est
/// **recopié dans la session** : une URL de 53 chiffres ne se compare pas d'un
/// test au suivant, et le carnet doit survivre à la fermeture du site.
abstract final class BatteryLinkDecoder {
  static const _batteryTypes = {
    '1': 'Normal',
    '2': 'AGM plaque plate',
    '3': 'AGM spirale',
    '4': 'GEL',
    '5': 'EFB',
    '6': 'Batterie au lithium',
  };
  static const _results = {
    '1': 'Bonne batterie',
    '2': 'À remplacer',
    '3': 'Bonne, à recharger',
    '4': 'À charger et revérifier',
    '5': 'Mauvaise cellule',
  };
  static const _vehicleTypes = {'1': 'Moto', '2': 'Voiture', '3': 'Camion'};
  static const _crankingResults = {'1': 'Normal', '2': 'Faible', '3': 'Haut'};
  static const _chargingResults = {
    '0': 'Aucune sortie',
    '1': 'Normal',
    '2': 'Tension élevée',
    '3': 'Tension basse',
  };
  // Seule valeur observée pour l'instant : le champ existe, ses autres codes
  // (DIN, EN, JIS…) restent à identifier sur d'autres rapports.
  static const _standards = {'0': 'CCA'};

  /// Le lien est-il d'un format qu'on sait décoder ?
  static bool canDecode(String url) => _payload(url) != null;

  /// Décode [url], ou renvoie `null` si le format n'est pas reconnu — l'appelant
  /// conserve alors le lien sans mesures plutôt que d'inventer des valeurs.
  static BatteryReport? decode(String url) {
    final d = _payload(url);
    if (d == null) return null;

    // Champs à positions fixes : tout ce qui dépasse la longueur reçue est
    // simplement absent (rapport tronqué ou format plus court).
    String? at(int i) => i < d.length ? d[i] : null;
    int? intAt(int start, int end) {
      if (end >= d.length) return null;
      return int.tryParse(d.substring(start, end + 1));
    }

    double? hundredths(int start, int end) {
      final v = intAt(start, end);
      return v == null ? null : v / 100;
    }

    final result = _results[at(14) ?? ''];
    final m = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value != null) m[key] = value;
    }

    put('battery_type', _batteryTypes[at(0) ?? '']);
    put('rated', intAt(1, 4));
    put('voltage', hundredths(5, 8));
    put('measured', intAt(9, 12));
    put('standard', _standards[at(13) ?? '']);
    put('result', result);
    put('soc', intAt(15, 17));
    put('soh', intAt(18, 20));
    put('internal_mohm', hundredths(21, 25));
    put('vehicle_type', _vehicleTypes[at(26) ?? '']);

    // Tests de démarreur et de charge : tous les champs à zéro = test non
    // effectué (c'est le cas d'un simple test de batterie). On ne stocke pas
    // « 0,00 V au démarrage », qui se lirait comme une mesure.
    final crankingVolts = hundredths(27, 30);
    if (crankingVolts != null && crankingVolts > 0) {
      put('cranking_voltage', crankingVolts);
      put('cranking_ms', intAt(31, 34));
      put('cranking_result', _crankingResults[at(35) ?? '']);
    }
    final loaded = hundredths(38, 41);
    final unloaded = hundredths(42, 45);
    if ((loaded != null && loaded > 0) || (unloaded != null && unloaded > 0)) {
      put('charging_loaded_voltage', loaded);
      put('charging_unloaded_voltage', unloaded);
      put('ripple', intAt(46, 49));
      put('charging_result', _chargingResults[at(50) ?? '']);
    }

    if (m.isEmpty) return null;
    return BatteryReport(result: result, measurements: m);
  }

  /// Charge utile du lien : le paramètre `d`, une chaîne **purement
  /// numérique**. On exige une longueur plancher pour ne pas prendre un `?d=1`
  /// quelconque pour un rapport.
  static String? _payload(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    final d = uri.queryParameters['d'];
    if (d == null || d.length < 27 || !RegExp(r'^\d+$').hasMatch(d)) return null;
    // L'hôte n'est pas exigé : le même testeur est distribué sous plusieurs
    // domaines. La forme du paramètre suffit à reconnaître le format, et un
    // faux positif ne produirait que des mesures relues par l'utilisateur.
    return d;
  }
}
