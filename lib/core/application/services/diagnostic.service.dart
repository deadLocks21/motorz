import 'package:motorz/core/domain/model/diagnostic_code.dart';
import 'package:motorz/core/domain/model/diagnostic_session.dart';

/// État d'un code défaut, **dérivé** de l'historique des sessions — jamais
/// stocké, comme la « dernière fois faite » d'une échéance (§5.11).
enum CodeState {
  /// Vu au dernier passage sur son calculateur.
  active,

  /// Des diagnostics ont suivi, mais aucun n'a relu ce calculateur : le défaut
  /// **reste actif**, on ne l'a simplement pas recontrôlé.
  unverified,

  /// Un diagnostic postérieur a relu le même calculateur sans le remonter.
  resolved;

  String get label => switch (this) {
    CodeState.active => 'Actif',
    CodeState.resolved => 'Disparu',
    CodeState.unverified => 'Non revérifié',
  };
}

/// Histoire d'un code sur un véhicule, tous relevés confondus.
class CodeHistory {
  final String code;

  /// Description la plus récente rencontrée (les outils ne la donnent pas
  /// toujours).
  final String? description;

  /// Statut rapporté à la dernière apparition.
  final DiagnosticCodeStatus status;

  /// Calculateurs qui l'ont remonté — « le même défaut remonté par cinq
  /// calculateurs reste un défaut », mais on garde qui l'a vu.
  final List<String> modules;
  final DateTime firstSeen;
  final DateTime lastSeen;
  final CodeState state;

  /// Nombre de relevés distincts où il apparaît (pas de lignes : un rapport qui
  /// répète le code sur cinq modules compte pour un).
  final int sessionCount;

  const CodeHistory({
    required this.code,
    required this.status,
    required this.modules,
    required this.firstSeen,
    required this.lastSeen,
    required this.state,
    required this.sessionCount,
    this.description,
  });

  /// Un défaut non recontrôlé n'est pas un défaut réglé : seul un relevé
  /// postérieur du même calculateur peut le faire tomber (§5.11).
  bool get isActive => state != CodeState.resolved;
}

/// Un code tel qu'affiché **dans une session** : regroupé, avec les modules qui
/// l'ont remonté.
typedef GroupedCode = ({
  String code,
  String? description,
  DiagnosticCodeStatus status,
  List<String> modules,
});

abstract final class DiagnosticService {
  /// Codes d'une session, **regroupés par code**. Un scanner répète volontiers
  /// le même trio sur `OBD-II` puis sur chaque adresse de calculateur moteur :
  /// on affiche 3 défauts, pas 15.
  static List<GroupedCode> groupBySession(Iterable<DiagnosticCode> codes) {
    final live = codes.where((c) => c.deletedAt == null);
    final byCode = <String, List<DiagnosticCode>>{};
    for (final c in live) {
      byCode.putIfAbsent(c.code, () => []).add(c);
    }
    final out = <GroupedCode>[
      for (final entry in byCode.entries)
        (
          code: entry.key,
          description: entry.value.map((c) => c.description).whereType<String>().firstOrNull,
          status: _strongestStatus(entry.value.map((c) => c.status)),
          modules: entry.value.map((c) => c.module).whereType<String>().toList(),
        ),
    ];
    out.sort((a, b) => a.code.compareTo(b.code));
    return out;
  }

  /// Histoire de chaque code du véhicule, du plus préoccupant au plus ancien :
  /// actifs d'abord, puis non revérifiés, puis disparus ; à état égal, le plus
  /// récemment vu en tête.
  ///
  /// [sessions] et [codes] portent **tout** l'historique du véhicule (les
  /// sessions supprimées et les codes supprimés sont ignorés).
  static List<CodeHistory> history(
    Iterable<DiagnosticSession> sessions,
    Iterable<DiagnosticCode> codes,
  ) {
    final liveSessions = sessions.where((s) => s.deletedAt == null).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final byId = {for (final s in liveSessions) s.id.value: s};

    // Occurrences par code : (session, module) — on ne garde que les codes
    // rattachés à une session vivante.
    final occurrences = <String, List<(DiagnosticSession, DiagnosticCode)>>{};
    for (final c in codes.where((c) => c.deletedAt == null)) {
      final session = byId[c.sessionId.value];
      if (session == null) continue;
      occurrences.putIfAbsent(c.code, () => []).add((session, c));
    }

    final out = <CodeHistory>[];
    for (final entry in occurrences.entries) {
      final rows = entry.value..sort((a, b) => a.$1.date.compareTo(b.$1.date));
      final lastSession = rows.last.$1;
      final modules = <String>[];
      for (final (_, code) in rows) {
        final m = code.module;
        if (m != null && !modules.any((e) => e.toLowerCase() == m.toLowerCase())) modules.add(m);
      }
      final atLastSession = rows.where((r) => r.$1.id == lastSession.id).map((r) => r.$2).toList();

      out.add(CodeHistory(
        code: entry.key,
        description: rows.reversed.map((r) => r.$2.description).whereType<String>().firstOrNull,
        status: _strongestStatus(atLastSession.map((c) => c.status)),
        modules: modules,
        firstSeen: rows.first.$1.date,
        lastSeen: lastSession.date,
        sessionCount: rows.map((r) => r.$1.id.value).toSet().length,
        state: _stateOf(
          modules: modules,
          lastSeen: lastSession,
          sessions: liveSessions,
        ),
      ));
    }

    out.sort((a, b) {
      final byState = a.state.index.compareTo(b.state.index);
      if (byState != 0) return byState;
      final byDate = b.lastSeen.compareTo(a.lastSeen);
      return byDate != 0 ? byDate : a.code.compareTo(b.code);
    });
    return out;
  }

  /// Codes actifs d'un véhicule — ce qui remonte comme indicateur in-app
  /// (§5.10). Inclut les non revérifiés : tant qu'on n'a pas relu le
  /// calculateur, le défaut est toujours là.
  static List<CodeHistory> activeCodes(
    Iterable<DiagnosticSession> sessions,
    Iterable<DiagnosticCode> codes,
  ) =>
      history(sessions, codes).where((h) => h.isActive).toList();

  /// Un diagnostic postérieur a-t-il relu le calculateur sans revoir le code ?
  ///
  /// La comparaison se fait **par module** : un diagnostic partiel (seul l'ABS
  /// relu) ne résout rien ailleurs. Une lecture incomplète dégrade la
  /// résolution, jamais la justesse.
  static CodeState _stateOf({
    required List<String> modules,
    required DiagnosticSession lastSeen,
    required List<DiagnosticSession> sessions,
  }) {
    final later = sessions
        .where((s) => s.date.isAfter(lastSeen.date) && s.type == lastSeen.type)
        .toList();
    if (later.isEmpty) return CodeState.active;

    for (final session in later) {
      if (modules.isEmpty) {
        // Code sans calculateur identifié (rapport lu en repli générique) :
        // seule une session elle aussi sans détail de module peut le
        // recontrôler — face à un scan ciblé, on ne conclut pas.
        if (session.modulesScanned.isEmpty && session.analyzedAt != null) return CodeState.resolved;
        continue;
      }
      if (modules.any(session.scanned)) return CodeState.resolved;
    }
    return CodeState.unverified;
  }

  /// Statut le plus « fort » d'un lot : un défaut permanent prime sur un
  /// confirmé, qui prime sur une simple attente. Deux calculateurs peuvent
  /// rapporter le même code à des stades différents.
  static DiagnosticCodeStatus _strongestStatus(Iterable<DiagnosticCodeStatus> statuses) {
    const order = [
      DiagnosticCodeStatus.permanent,
      DiagnosticCodeStatus.confirmed,
      DiagnosticCodeStatus.pending,
      DiagnosticCodeStatus.unknown,
    ];
    for (final s in order) {
      if (statuses.contains(s)) return s;
    }
    return DiagnosticCodeStatus.unknown;
  }
}
