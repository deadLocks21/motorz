import 'package:motorz/core/domain/model/maintenance_catalog_item.dart';
import 'package:motorz/core/domain/model/maintenance_operation.dart';
import 'package:motorz/core/domain/model/maintenance_operation_line.dart';
import 'package:motorz/core/domain/model/maintenance_plan.dart';

/// Dernière réalisation dérivée d'un poste (km + date de l'opération).
class LastDone {
  final int odometer;
  final DateTime date;
  const LastDone({required this.odometer, required this.date});
}

/// Dérivations de l'entretien — **pures et locales** (offline-first). Aucun état
/// « dernière fois faite » n'est stocké : tout se recalcule depuis l'historique
/// des opérations, ce qui rend la **saisie rétroactive** sûre (insérer/supprimer
/// une opération recalcule mécaniquement la bonne échéance).
abstract final class MaintenanceDerivationService {
  /// Dernière réalisation d'un plan = l'opération **non supprimée** la plus
  /// récente (par **km**, puis date) portant une ligne du même poste de
  /// catalogue. `null` pour un plan sans poste (à-venir/one-shot) ou sans
  /// historique. Le km est prioritaire ⇒ une saisie rétro à km inférieur
  /// n'écrase pas une réalisation plus récente.
  static LastDone? lastDoneForPlan(
    Plan plan,
    List<Operation> operations,
    List<OperationLine> lines,
  ) {
    final catalogId = plan.catalogItemId;
    if (catalogId == null) return null;
    final opsById = _opsById(operations);
    return _best(
      lines.where((l) =>
          l.deletedAt == null &&
          l.catalogItemId == catalogId &&
          opsById.containsKey(l.operationId.value)),
      opsById,
    );
  }

  /// Dernière réalisation de **tous** les plans en une passe : pré-bucketise les
  /// lignes par poste de catalogue (O(L + P)) plutôt qu'un scan par plan.
  static List<({Plan plan, LastDone? lastDone})> lastDoneAll(
    List<Plan> plans,
    List<Operation> operations,
    List<OperationLine> lines,
  ) {
    final opsById = _opsById(operations);
    final byCatalog = <String, List<OperationLine>>{};
    for (final l in lines) {
      final cid = l.catalogItemId;
      if (l.deletedAt != null || cid == null) continue;
      if (!opsById.containsKey(l.operationId.value)) continue;
      (byCatalog[cid.value] ??= []).add(l);
    }
    return [
      for (final p in plans)
        (
          plan: p,
          lastDone: p.catalogItemId == null
              ? null
              : _best(byCatalog[p.catalogItemId!.value] ?? const [], opsById),
        ),
    ];
  }

  /// Titre dérivé des lignes : nom du premier poste + « + N autres ».
  static String deriveTitle(
    List<OperationLine> lines,
    Map<String, CatalogItem> catalogById,
  ) {
    final labels = [
      for (final l in lines)
        l.catalogItemId != null
            ? (catalogById[l.catalogItemId!.value]?.name ?? 'Poste')
            : (l.label ?? 'Poste'),
    ];
    if (labels.isEmpty) return 'Opération';
    if (labels.length == 1) return labels.first;
    final others = labels.length - 1;
    return '${labels.first} + $others autre${others > 1 ? 's' : ''}';
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

  /// Coût par poste de catalogue (stats §5.9). Lignes libres ⇒ clé `null`.
  static Map<String?, double> costPerCatalogItem(List<OperationLine> lines) {
    final out = <String?, double>{};
    for (final l in lines) {
      if (l.deletedAt != null) continue;
      final c = l.cost;
      if (c == null) continue;
      final key = l.catalogItemId?.value;
      out[key] = (out[key] ?? 0) + c;
    }
    return out;
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
