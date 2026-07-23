import 'package:flutter_test/flutter_test.dart';
import 'package:motorz/core/application/services/diagnostic.service.dart';
import 'package:motorz/core/domain/model/diagnostic_code.dart';
import 'package:motorz/core/domain/model/diagnostic_session.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';

void main() {
  final vehicleId = UuidValue.generate();

  DiagnosticSession session(
    DateTime date, {
    List<String> modules = const [],
    bool analyzed = true,
    DateTime? deletedAt,
  }) =>
      DiagnosticSession(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        date: date,
        updatedAt: date,
        modulesScanned: modules,
        analyzedAt: analyzed ? date : null,
        deletedAt: deletedAt,
      );

  DiagnosticCode code(
    DiagnosticSession s,
    String code, {
    String? module,
    String? description,
    DiagnosticCodeStatus status = DiagnosticCodeStatus.pending,
    DateTime? deletedAt,
  }) =>
      DiagnosticCode(
        id: UuidValue.generate(),
        sessionId: s.id,
        code: code,
        module: module,
        description: description,
        status: status,
        updatedAt: s.date,
        deletedAt: deletedAt,
      );

  group('regroupement dans une session', () {
    test('le même défaut remonté par cinq calculateurs reste un défaut', () {
      final s = session(DateTime(2025, 5, 28));
      final codes = [
        for (final module in ['OBD-II', 'Moteur#1', 'Moteur#3', 'Moteur#4'])
          for (final c in ['P2291', 'P0017', 'P050B']) code(s, c, module: module),
      ];
      expect(codes, hasLength(12));

      final grouped = DiagnosticService.groupBySession(codes);
      expect(grouped, hasLength(3));
      expect(grouped.map((g) => g.code), ['P0017', 'P050B', 'P2291']);
      expect(grouped.first.modules, ['OBD-II', 'Moteur#1', 'Moteur#3', 'Moteur#4']);
    });

    test('statut le plus fort retenu quand deux calculateurs divergent', () {
      final s = session(DateTime(2025, 5, 28));
      final grouped = DiagnosticService.groupBySession([
        code(s, 'P0017', module: 'A', status: DiagnosticCodeStatus.pending),
        code(s, 'P0017', module: 'B', status: DiagnosticCodeStatus.confirmed),
      ]);
      expect(grouped.single.status, DiagnosticCodeStatus.confirmed);
    });

    test('les codes supprimés sont ignorés', () {
      final s = session(DateTime(2025, 5, 28));
      final grouped = DiagnosticService.groupBySession([
        code(s, 'P0017', deletedAt: DateTime(2025, 6, 1)),
      ]);
      expect(grouped, isEmpty);
    });
  });

  group('état dérivé d\'un code', () {
    test('rien depuis : actif', () {
      final s = session(DateTime(2025, 5, 28), modules: ['ABS']);
      final history = DiagnosticService.history([s], [code(s, 'C1234', module: 'ABS')]);
      expect(history.single.state, CodeState.active);
      expect(history.single.isActive, isTrue);
    });

    test('un relevé postérieur du même calculateur le fait tomber', () {
      final first = session(DateTime(2025, 5, 28), modules: ['ABS']);
      final later = session(DateTime(2025, 8, 1), modules: ['ABS', 'Moteur#1']);
      final history =
          DiagnosticService.history([first, later], [code(first, 'C1234', module: 'ABS')]);
      expect(history.single.state, CodeState.resolved);
      expect(history.single.isActive, isFalse);
    });

    test('un diagnostic partiel ne résout rien ailleurs', () {
      // On relit le moteur, pas l'ABS : le code ABS n'est pas « réglé », il
      // n'a simplement pas été recontrôlé — et reste donc actif.
      final first = session(DateTime(2025, 5, 28), modules: ['ABS']);
      final later = session(DateTime(2025, 8, 1), modules: ['Moteur#1']);
      final history =
          DiagnosticService.history([first, later], [code(first, 'C1234', module: 'ABS')]);
      expect(history.single.state, CodeState.unverified);
      expect(history.single.isActive, isTrue);
    });

    test('comparaison de calculateur insensible à la casse et aux espaces', () {
      final first = session(DateTime(2025, 5, 28), modules: ['ABS']);
      final later = session(DateTime(2025, 8, 1), modules: [' abs ']);
      final history =
          DiagnosticService.history([first, later], [code(first, 'C1234', module: 'ABS')]);
      expect(history.single.state, CodeState.resolved);
    });

    test('réapparition : le code repart actif et garde sa première date', () {
      final first = session(DateTime(2025, 5, 28), modules: ['ABS']);
      final clean = session(DateTime(2025, 8, 1), modules: ['ABS']);
      final again = session(DateTime(2025, 11, 3), modules: ['ABS']);
      final history = DiagnosticService.history(
        [first, clean, again],
        [code(first, 'C1234', module: 'ABS'), code(again, 'C1234', module: 'ABS')],
      );
      expect(history.single.state, CodeState.active);
      expect(history.single.firstSeen, DateTime(2025, 5, 28));
      expect(history.single.lastSeen, DateTime(2025, 11, 3));
      expect(history.single.sessionCount, 2);
    });

    test('un code sans calculateur identifié n\'est résolu que par un scan global', () {
      final first = session(DateTime(2025, 5, 28));
      final targeted = session(DateTime(2025, 8, 1), modules: ['ABS']);
      final history = DiagnosticService.history([first, targeted], [code(first, 'P0301')]);
      expect(history.single.state, CodeState.unverified);

      final global = session(DateTime(2025, 9, 1));
      final after = DiagnosticService.history([first, targeted, global], [code(first, 'P0301')]);
      expect(after.single.state, CodeState.resolved);
    });

    test('un rapport non analysé ne résout rien', () {
      final first = session(DateTime(2025, 5, 28));
      final pending = session(DateTime(2025, 8, 1), analyzed: false);
      final history = DiagnosticService.history([first, pending], [code(first, 'P0301')]);
      expect(history.single.state, CodeState.unverified);
    });

    test('un test de batterie ne recontrôle pas un diagnostic OBD', () {
      final obd = session(DateTime(2025, 5, 28), modules: ['ABS']);
      final battery = DiagnosticSession(
        id: UuidValue.generate(),
        vehicleId: vehicleId,
        date: DateTime(2025, 8, 1),
        updatedAt: DateTime(2025, 8, 1),
        type: DiagnosticType.battery,
        modulesScanned: const ['ABS'],
        analyzedAt: DateTime(2025, 8, 1),
      );
      final history =
          DiagnosticService.history([obd, battery], [code(obd, 'C1234', module: 'ABS')]);
      expect(history.single.state, CodeState.active);
    });

    test('session supprimée : ses codes sortent de l\'historique', () {
      final s = session(DateTime(2025, 5, 28), deletedAt: DateTime(2025, 6, 1));
      expect(DiagnosticService.history([s], [code(s, 'P0017')]), isEmpty);
    });
  });

  group('tri et indicateur', () {
    test('actifs d\'abord, puis non revérifiés, puis disparus', () {
      final s1 = session(DateTime(2025, 1, 10), modules: ['ABS', 'Moteur']);
      final s2 = session(DateTime(2025, 6, 10), modules: ['ABS']);
      final s3 = session(DateTime(2025, 9, 10), modules: ['ABS']);
      final codes = [
        code(s1, 'C0001', module: 'ABS'), // relu deux fois depuis → disparu
        code(s1, 'P0002', module: 'Moteur'), // moteur jamais relu → non revérifié
        code(s3, 'C0003', module: 'ABS'), // dernier relevé → actif
      ];
      final history = DiagnosticService.history([s1, s2, s3], codes);
      expect(history.map((h) => h.code), ['C0003', 'P0002', 'C0001']);
      expect(history.map((h) => h.state),
          [CodeState.active, CodeState.unverified, CodeState.resolved]);

      // L'indicateur in-app compte les non revérifiés : tant qu'on n'a pas relu
      // le calculateur, le défaut est toujours là.
      expect(DiagnosticService.activeCodes([s1, s2, s3], codes).map((h) => h.code),
          ['C0003', 'P0002']);
    });

    test('description reprise du relevé le plus récent qui en porte une', () {
      final s1 = session(DateTime(2025, 1, 10), modules: ['ABS']);
      final s2 = session(DateTime(2025, 6, 10), modules: ['ABS']);
      final history = DiagnosticService.history([s1, s2], [
        code(s1, 'C0001', module: 'ABS'),
        code(s2, 'C0001', module: 'ABS', description: 'Capteur de roue AVG'),
      ]);
      expect(history.single.description, 'Capteur de roue AVG');
    });
  });
}
