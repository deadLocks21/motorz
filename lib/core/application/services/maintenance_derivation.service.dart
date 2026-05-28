import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';

/// Dernière réalisation dérivée d'une échéance (km + date de l'opération).
class LastDone {
  final int odometer;
  final DateTime date;
  const LastDone({required this.odometer, required this.date});
}

/// Dérivations de l'entretien — **pures et locales** (offline-first). Aucun état
/// « dernière fois faite » n'est stocké : il se recalcule depuis l'historique des
/// opérations, ce qui rend la **saisie rétroactive** sûre. Le rapprochement
/// échéance ↔ opération se fait **par intitulé** (titre de l'échéance == libellé
/// d'une ligne, insensible à la casse/aux espaces).
abstract final class MaintenanceDerivationService {
  static String _norm(String s) => s.trim().toLowerCase();

  /// Dernière réalisation d'une échéance = l'opération **non supprimée** la plus
  /// récente (par **km**, puis date) portant une ligne au même intitulé que
  /// [plan]. `null` si aucune. Le km prioritaire ⇒ une saisie rétro à km
  /// inférieur n'écrase pas une réalisation plus récente.
  static LastDone? lastDoneForPlan(
    Plan plan,
    List<Operation> operations,
    List<OperationLine> lines,
  ) {
    final opsById = _opsById(operations);
    final target = _norm(plan.title);
    return _best(
      lines.where((l) =>
          l.deletedAt == null &&
          _norm(l.label) == target &&
          opsById.containsKey(l.operationId.value)),
      opsById,
    );
  }

  /// Dernière réalisation de **toutes** les échéances en une passe : pré-bucketise
  /// les lignes par intitulé normalisé (O(L + P)).
  static List<({Plan plan, LastDone? lastDone})> lastDoneAll(
    List<Plan> plans,
    List<Operation> operations,
    List<OperationLine> lines,
  ) {
    final opsById = _opsById(operations);
    final byLabel = <String, List<OperationLine>>{};
    for (final l in lines) {
      if (l.deletedAt != null || !opsById.containsKey(l.operationId.value)) continue;
      (byLabel[_norm(l.label)] ??= []).add(l);
    }
    return [
      for (final p in plans)
        (plan: p, lastDone: _best(byLabel[_norm(p.title)] ?? const [], opsById)),
    ];
  }

  /// Une **tâche ponctuelle** est faite (→ à masquer de À prévoir) dès qu'une
  /// opération **non supprimée** porte une ligne au même intitulé que le titre,
  /// **et que cette opération a été enregistrée après la création de la tâche**
  /// (`op.updatedAt >= plan.updatedAt`) — pour ne pas la considérer « déjà faite »
  /// à cause d'un historique ancien au libellé identique.
  static bool isOneShotDone(
    Plan plan,
    List<Operation> operations,
    List<OperationLine> lines,
  ) {
    final opsById = _opsById(operations);
    final target = _norm(plan.title);
    for (final l in lines) {
      if (l.deletedAt != null || _norm(l.label) != target) continue;
      final op = opsById[l.operationId.value];
      if (op == null) continue;
      if (!op.updatedAt.isBefore(plan.updatedAt)) return true;
    }
    return false;
  }

  /// Titre dérivé des lignes : libellé de la première + « + N autres ».
  static String deriveTitle(List<OperationLine> lines) {
    if (lines.isEmpty) return 'Opération';
    if (lines.length == 1) return lines.first.label;
    final others = lines.length - 1;
    return '${lines.first.label} + $others autre${others > 1 ? 's' : ''}';
  }

  /// Coût effectif d'une opération = somme des coûts de ses lignes (null si rien).
  static double? operationCost(Iterable<OperationLine> linesOfOperation) {
    double sum = 0;
    var any = false;
    for (final l in linesOfOperation) {
      if (l.deletedAt != null) continue;
      final c = l.cost;
      if (c != null) {
        sum += c;
        any = true;
      }
    }
    return any ? sum : null;
  }

  static Map<String, Operation> _opsById(List<Operation> ops) => {
        for (final o in ops)
          if (o.deletedAt == null) o.id.value: o,
      };

  static LastDone? _best(Iterable<OperationLine> lines, Map<String, Operation> opsById) {
    Operation? best;
    for (final l in lines) {
      final op = opsById[l.operationId.value];
      if (op == null) continue;
      if (best == null ||
          op.odometer > best.odometer ||
          (op.odometer == best.odometer && op.date.isAfter(best.date))) {
        best = op;
      }
    }
    return best == null ? null : LastDone(odometer: best.odometer, date: best.date);
  }
}
