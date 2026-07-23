import 'package:motorz/core/domain/model/diagnostic_code.dart';

/// Un code lu dans un rapport, avant enregistrement (pas encore d'id).
class ParsedCode {
  final String code;
  final String? module;
  final String? description;
  final DiagnosticCodeStatus status;
  final String? rawStatus;

  const ParsedCode({
    required this.code,
    this.module,
    this.description,
    this.status = DiagnosticCodeStatus.unknown,
    this.rawStatus,
  });
}

/// Résultat de l'analyse d'un rapport texte. Sert à **pré-remplir** un
/// formulaire que l'utilisateur relit : aucun import n'est appliqué en silence
/// (§5.11).
class ParsedReport {
  /// Outil ayant produit le rapport (« Car Scanner ELM OBD2 1.118.0 »).
  final String? tool;
  final String? connectionProfile;
  final DateTime? date;

  /// Calculateurs interrogés, **y compris ceux sans défaut**.
  final List<String> modules;
  final List<ParsedCode> codes;

  /// Vrai quand le format n'a pas été reconnu et qu'on s'est rabattu sur la
  /// simple reconnaissance des codes : l'UI le signale, la richesse manque mais
  /// la saisie reste possible.
  final bool usedFallback;

  const ParsedReport({
    this.tool,
    this.connectionProfile,
    this.date,
    this.modules = const [],
    this.codes = const [],
    this.usedFallback = false,
  });

  bool get isEmpty => codes.isEmpty && modules.isEmpty;

  /// Codes distincts (le même défaut remonté par cinq calculateurs reste un
  /// défaut), dans l'ordre de première apparition.
  List<String> get distinctCodes {
    final seen = <String>{};
    return [for (final c in codes) if (seen.add(c.code)) c.code];
  }
}

/// Analyse des rapports de diagnostic **textuels** (collés, ou extraits d'un
/// PDF côté API — c'est le même analyseur des deux côtés, en un seul
/// exemplaire).
///
/// Un analyseur par format connu (Car Scanner en premier), et à défaut un repli
/// générique qui attrape au moins les codes : un format inconnu dégrade la
/// richesse, jamais la possibilité de saisir.
abstract final class DiagnosticReportParser {
  /// Motif d'un code défaut normalisé (SAE J2012) : domaine + 4 hexa.
  static final RegExp codePattern = RegExp(r'\b([PBCU][0-3][0-9A-F]{3})\b');

  static final RegExp _separator = RegExp(r'^\s*={3,}\s*$');
  static final RegExp _codeSeparator = RegExp(r'^\s*-{3,}\s*$');
  static final RegExp _codeLine = RegExp(r'^([PBCU][0-3][0-9A-F]{3})\b');
  static final RegExp _noFault = RegExp(
    r'aucun code|aucun défaut|no (fault|trouble) code|no dtc',
    caseSensitive: false,
  );
  static final RegExp _statusLine = RegExp(r'^(statut|status|état)\s*:\s*(.+)$', caseSensitive: false);
  static final RegExp _dtcCount = RegExp(r'^dtcs?\s*:', caseSensitive: false);

  static ParsedReport parse(String raw) {
    final text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (text.trim().isEmpty) return const ParsedReport();

    // Un analyseur par format connu, choisi sur signature. PSA-DIAG (valise
    // officielle Peugeot/Citroën) doit passer *avant* le repli générique : ses
    // codes sont des hexa constructeur (`F40A`) que le motif SAE ne voit pas.
    if (PsaDiagParser.matches(text)) {
      final psa = PsaDiagParser.parse(text);
      if (!psa.isEmpty) return psa;
    }

    final blocks = text.split('\n').fold<List<List<String>>>([[]], (acc, line) {
      if (_separator.hasMatch(line)) {
        acc.add([]);
      } else {
        acc.last.add(line);
      }
      return acc;
    });

    final header = _parseHeader(blocks.first);
    final modules = <String>[];
    final codes = <ParsedCode>[];

    for (final block in blocks) {
      final lines = block.where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;

      final module = _dedupeModuleName(lines.first.trim());
      final body = lines.skip(1).join('\n');
      final hasCodes = _codeLine.hasMatch(_firstCodeLine(lines) ?? '');
      // Un bloc n'est un module que s'il porte des codes ou dit explicitement
      // n'en avoir aucun — sinon c'est l'en-tête du rapport, pas un calculateur.
      if (!hasCodes && !_noFault.hasMatch(body)) continue;

      if (!modules.any((m) => m.toLowerCase() == module.toLowerCase())) modules.add(module);
      codes.addAll(_parseCodes(lines.skip(1).toList(), module));
    }

    if (modules.isEmpty && codes.isEmpty) return _fallback(text, header);

    return ParsedReport(
      tool: header.tool,
      connectionProfile: header.profile,
      date: header.date,
      modules: modules,
      codes: codes,
    );
  }

  /// Repli : on ne sait pas lire la structure, mais les codes se reconnaissent
  /// à leur forme. Sans module ni description — mieux vaut trois codes nus que
  /// rien du tout.
  static ParsedReport _fallback(String text, _Header header) {
    final seen = <String>{};
    final codes = <ParsedCode>[
      for (final m in codePattern.allMatches(text))
        if (seen.add(m.group(1)!)) ParsedCode(code: m.group(1)!),
    ];
    return ParsedReport(
      tool: header.tool,
      connectionProfile: header.profile,
      date: header.date,
      codes: codes,
      usedFallback: true,
    );
  }

  static String? _firstCodeLine(List<String> lines) =>
      lines.skip(1).map((l) => l.trim()).where((l) => _codeLine.hasMatch(l)).firstOrNull;

  /// Découpe le corps d'un module en codes (séparés par des tirets), en
  /// tolérant l'absence de séparateurs : la ligne de code fait office de borne.
  static List<ParsedCode> _parseCodes(List<String> lines, String module) {
    final out = <ParsedCode>[];
    String? code;
    final details = <String>[];

    void flush() {
      if (code == null) return;
      String? description;
      String? rawStatus;
      for (final d in details) {
        final status = _statusLine.firstMatch(d);
        if (status != null) {
          rawStatus = status.group(2)!.trim();
        } else {
          // Première ligne libre = description ; les suivantes sont ignorées
          // (un rapport peut détailler des conditions de gel qu'on ne stocke pas).
          description ??= d;
        }
      }
      out.add(ParsedCode(
        code: DiagnosticCode.normalizeCode(code!),
        module: module,
        description: description,
        status: normalizeStatus(rawStatus),
        rawStatus: rawStatus,
      ));
      code = null;
      details.clear();
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty || _codeSeparator.hasMatch(raw) || _dtcCount.hasMatch(line)) continue;
      final match = _codeLine.firstMatch(line);
      if (match != null) {
        flush();
        code = match.group(1);
      } else if (code != null) {
        details.add(line);
      }
    }
    flush();
    return out;
  }

  /// Statut normalisé depuis le libellé de l'outil, quelle que soit sa langue.
  ///
  /// L'ordre des tests compte : « En attente de défaut **présent** » est un
  /// code *pending*, pas *confirmed* — chercher « présent » d'abord le
  /// classerait à l'envers.
  static DiagnosticCodeStatus normalizeStatus(String? raw) {
    if (raw == null) return DiagnosticCodeStatus.unknown;
    final s = raw.toLowerCase();
    if (s.contains('attente') || s.contains('pending')) return DiagnosticCodeStatus.pending;
    if (s.contains('permanent')) return DiagnosticCodeStatus.permanent;
    if (s.contains('confirm') ||
        s.contains('présent') ||
        s.contains('present') ||
        s.contains('mémoris') ||
        s.contains('stored')) {
      return DiagnosticCodeStatus.confirmed;
    }
    return DiagnosticCodeStatus.unknown;
  }

  /// Car Scanner répète le nom du calculateur collé à lui-même
  /// (« OBD-IIOBD-II ») sur les blocs qui portent des défauts. On le réduit.
  static String _dedupeModuleName(String name) {
    if (name.isEmpty || name.length.isOdd) return name;
    final half = name.length ~/ 2;
    return name.substring(0, half) == name.substring(half) ? name.substring(0, half) : name;
  }

  static _Header _parseHeader(List<String> lines) {
    String? tool;
    String? profile;
    DateTime? date;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      // « Connection profile: X » et « Date: … » arrivent collés sur la même
      // ligne dans l'export Car Scanner (« …EOBDDate: 28/05/2025 »). Pas de
      // `\b` devant `date` : il n'y a justement pas de frontière de mot là où
      // l'export a soudé les deux champs.
      final dateIdx = RegExp(r'date\s*:', caseSensitive: false).firstMatch(line);
      final profileMatch =
          RegExp(r'(connection profile|profil de connexion)\s*:\s*(.*)$', caseSensitive: false)
              .firstMatch(dateIdx == null ? line : line.substring(0, dateIdx.start));
      if (profileMatch != null) profile = profileMatch.group(2)!.trim();
      if (dateIdx != null) date ??= _parseDate(line.substring(dateIdx.end).trim());

      if (tool == null && !line.contains(':')) {
        tool = line;
      } else if (RegExp(r'^version\s*:', caseSensitive: false).hasMatch(line) && tool != null) {
        // « Version: 1.118.0/401180/GP » → on ne garde que le numéro utile.
        final version = line.split(':').skip(1).join(':').trim().split('/').first;
        tool = '$tool $version'.trim();
      }
    }
    return _Header(tool: tool, profile: profile, date: date);
  }

  /// `28/05/2025 20:20:20`, `2025-05-28 20:20`, ou ISO-8601.
  static DateTime? _parseDate(String raw) {
    final fr = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?')
        .firstMatch(raw);
    if (fr != null) {
      return DateTime(
        int.parse(fr.group(3)!),
        int.parse(fr.group(2)!),
        int.parse(fr.group(1)!),
        int.tryParse(fr.group(4) ?? '') ?? 0,
        int.tryParse(fr.group(5) ?? '') ?? 0,
        int.tryParse(fr.group(6) ?? '') ?? 0,
      );
    }
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  }
}

class _Header {
  final String? tool;
  final String? profile;
  final DateTime? date;
  const _Header({this.tool, this.profile, this.date});
}

/// Analyseur des rapports **PSA-DIAG** (valise officielle Peugeot/Citroën, dont
/// l'export « Défauts Expert »).
///
/// Format très différent de Car Scanner : les codes sont des **hexa
/// constructeur à 4 caractères sans préfixe** (`F40A`, `260B`), les descriptions
/// sont en clair, et le PDF est une **mise en page multi-colonnes** que
/// l'extraction aplatit — d'où un texte où codes, descriptions et propriétés
/// s'entremêlent. On s'appuie sur trois invariants robustes :
///
/// - chaque code est `<4 hexa> <description>` ;
/// - chaque calculateur en défaut s'annonce `… CODE (N Défauts)` — la somme des
///   N vaut le nombre de codes, ce qui **partitionne** les codes par module ;
/// - les blocs « Propriétés … Caractérisation du défaut … » suivent les codes
///   dans le **même ordre**, 1:1, et portent le statut (`Présent`/`Fugitif`).
///
/// Quand un invariant ne tient pas (compteurs incohérents, blocs en nombre
/// différent), on **dégrade la résolution sans inventer** : module ou statut
/// laissés vides plutôt que devinés (§5.11).
abstract final class PsaDiagParser {
  /// 4 hexa isolés (ni lettre ni chiffre accolé) suivis d'une description
  /// capitalisée. Les lookarounds excluent les fragments de VIN et les années
  /// de date (`2026 15:07` : « 15 » n'est pas une majuscule → écarté).
  static final RegExp _code = RegExp(
    r'(?<![0-9A-Z])([0-9A-F]{4})(?![0-9A-Z]) +([A-ZÀ-Ÿ].*?)'
    r'(?= (?:(?<![0-9A-Z])[0-9A-F]{4}(?![0-9A-Z]) +[A-ZÀ-Ÿ])| Propriétés| Liste des| Veuillez|\d+ of \d+|$)',
    dotAll: true,
  );

  /// Calculateur en défaut : `… CODE (N Défauts)`. Le compteur partitionne les
  /// codes par module.
  static final RegExp _moduleCount =
      RegExp(r'([A-Z][A-Z0-9_.]+) +\((\d+) +Défauts?\)');

  /// Bloc de propriétés d'un code : statut optionnel (`Fugitif`) + caractérisation.
  static final RegExp _props = RegExp(
    r'Propriétés +Origine +\S+ +(?:Statut +(\w+) +)?Caractérisation du défaut +(.*?)'
    r'(?= Liste des| Propriétés| Veuillez|\d+ of \d+|$)',
    dotAll: true,
  );

  static bool matches(String text) => text.contains('PSA-DIAG');

  static ParsedReport parse(String text) {
    final codeMatches = _code.allMatches(text).toList();
    if (codeMatches.isEmpty) return const ParsedReport();

    // Partition par calculateur : les compteurs `(N Défauts)`, dans l'ordre,
    // découpent la liste des codes. On n'y recourt que si la somme colle au
    // nombre de codes — sinon on laisse les modules vides (justesse > richesse).
    final counts = _moduleCount.allMatches(text).toList();
    final modules = [for (final m in counts) m.group(1)!];
    final moduleOf = <int, String>{};
    // On ne partitionne que si la somme des compteurs vaut *exactement* le
    // nombre de codes lus : un écart (compteur erroné, code manqué) signifie que
    // le rapprochement position→module n'est pas fiable, et mal ranger un défaut
    // coûte plus cher que de laisser le module vide (§5.11).
    final declared = counts.fold<int>(0, (sum, m) => sum + int.parse(m.group(2)!));
    if (declared == codeMatches.length) {
      var assigned = 0;
      for (final m in counts) {
        final n = int.parse(m.group(2)!);
        for (var i = 0; i < n; i++, assigned++) {
          moduleOf[assigned] = m.group(1)!;
        }
      }
    }

    // Blocs de propriétés, dans l'ordre du document = ordre des codes. Appariés
    // 1:1 seulement si le compte correspond.
    final propMatches = _props.allMatches(text).toList();
    final paired = propMatches.length == codeMatches.length;

    final codes = <ParsedCode>[
      for (var i = 0; i < codeMatches.length; i++)
        _buildCode(codeMatches[i], moduleOf[i], paired ? propMatches[i] : null),
    ];

    return ParsedReport(
      tool: _tool(text),
      date: _date(text),
      modules: modules,
      codes: codes,
    );
  }

  static ParsedCode _buildCode(RegExpMatch code, String? module, RegExpMatch? props) {
    var description = code.group(2)!.trim().replaceAll(RegExp(r'\.$'), '');

    DiagnosticCodeStatus status = DiagnosticCodeStatus.unknown;
    String? rawStatus;
    if (props != null) {
      final statutWord = props.group(1)?.trim();
      final caracterisation = props.group(2)?.trim();
      // « Fugitif » = défaut intermittent (vu, pas présent à l'instant) → en
      // attente ; sans mention de statut, PSA affiche un défaut **présent**.
      final fugitif = statutWord != null && statutWord.toLowerCase().startsWith('fug');
      status = fugitif ? DiagnosticCodeStatus.pending : DiagnosticCodeStatus.confirmed;
      rawStatus = fugitif ? 'Fugitif' : 'Présent';
      // La caractérisation (« Court-circuit au plus », « CC- ») précise le
      // défaut : on l'ajoute à la description quand elle apporte une info.
      if (caracterisation != null &&
          caracterisation.isNotEmpty &&
          !caracterisation.toLowerCase().startsWith('non caractéris')) {
        description = '$description — $caracterisation';
      }
    }

    return ParsedCode(
      code: DiagnosticCode.normalizeCode(code.group(1)!),
      module: module,
      description: description,
      status: status,
      rawStatus: rawStatus,
    );
  }

  static String? _tool(String text) {
    final version = RegExp(r"Version de l'outil\s*:\s*([\d.]+)_PSA-DIAG", caseSensitive: false)
        .firstMatch(text);
    if (version != null) return 'PSA-DIAG ${version.group(1)}';
    return text.contains('PSA-DIAG') ? 'PSA-DIAG' : null;
  }

  static DateTime? _date(String text) {
    // Pied de page « 22/03/2026 15:08 » : le plus régulier des trois formats de
    // date du rapport.
    final m = RegExp(r'(\d{2})/(\d{2})/(\d{4})(?:\s+(\d{1,2}):(\d{2}))?').firstMatch(text);
    if (m == null) return null;
    return DateTime(
      int.parse(m.group(3)!),
      int.parse(m.group(2)!),
      int.parse(m.group(1)!),
      int.tryParse(m.group(4) ?? '') ?? 0,
      int.tryParse(m.group(5) ?? '') ?? 0,
    );
  }
}
