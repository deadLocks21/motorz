import 'dart:async';

import 'package:motorz/core/application/services/logger_application.service.dart';
import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/rejected_op_store.dart';
import 'package:motorz/infrastructure/sync/sync_api.dart';
import 'package:motorz/infrastructure/sync/sync_cursor.dart';
import 'package:synchronized/synchronized.dart';

/// Phase courante de la synchro, exposée à l'UI.
enum SyncPhase { idle, syncing, offline, error }

/// Instantané de l'état de synchro observable par l'UI : la [phase] courante,
/// le nombre d'écritures encore [pending] (en file) et le nombre d'écritures
/// [rejected] en dead-letter. [hasProblem] résume « il y a quelque chose à
/// signaler » (réseau en échec ou rejets définitifs).
class SyncStatus {
  final SyncPhase phase;
  final int pending;
  final int rejected;
  const SyncStatus({
    required this.phase,
    required this.pending,
    required this.rejected,
  });

  bool get hasProblem => phase == SyncPhase.error || rejected > 0;

  SyncStatus copyWith({SyncPhase? phase, int? pending, int? rejected}) => SyncStatus(
        phase: phase ?? this.phase,
        pending: pending ?? this.pending,
        rejected: rejected ?? this.rejected,
      );

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.phase == phase &&
      other.pending == pending &&
      other.rejected == rejected;

  @override
  int get hashCode => Object.hash(phase, pending, rejected);
}

/// Service de synchro offline-first : à chaque retour en ligne (et une fois au
/// démarrage si en ligne), pousse la file (FIFO) puis tire les changements
/// delta dans le store local. Sérialisé par un [Lock].
///
/// Expose un [SyncStatus] observable ([watchStatus]) : phase courante, ops en
/// attente et rejets définitifs (dead-letter). Les lignes refusées en push
/// (forbidden/invalid) sont sorties de la file vers le [RejectedOpStore] pour
/// ne pas boucler, et restent visibles tant que l'utilisateur ne les a pas
/// réessayées ([retryRejected]) ou ignorées ([discardRejected]).
class SyncService {
  final SyncApi _api;
  final LocalRecordStore _store;
  final PendingQueue _queue;
  final RejectedOpStore _rejectedStore;
  final ConnectivityService _connectivity;
  final SyncCursorStore _cursor;
  final LoggerApplicationService? _logger;

  /// `false` en mode local-only (pas de backend configuré) : la synchro est
  /// neutralisée, le store local reste pleinement fonctionnel.
  final bool enabled;

  StreamSubscription<bool>? _subscription;
  final Lock _lock = Lock();
  bool _disposed = false;

  SyncStatus _status = const SyncStatus(phase: SyncPhase.idle, pending: 0, rejected: 0);
  final StreamController<SyncStatus> _statusController =
      StreamController<SyncStatus>.broadcast();

  SyncService({
    required SyncApi api,
    required LocalRecordStore store,
    required PendingQueue queue,
    required ConnectivityService connectivity,
    required SyncCursorStore cursor,
    RejectedOpStore? rejectedStore,
    LoggerApplicationService? logger,
    this.enabled = true,
  })  : _api = api,
        _store = store,
        _queue = queue,
        _rejectedStore = rejectedStore ?? InMemoryRejectedOpStore(),
        _connectivity = connectivity,
        _cursor = cursor,
        _logger = logger;

  /// État courant de la synchro (valeur instantanée).
  SyncStatus get status => _status;

  /// Flux de l'état de synchro : émet la valeur courante immédiatement, puis à
  /// chaque changement (comme [ConnectivityService.watch]).
  Stream<SyncStatus> watchStatus() async* {
    yield _status;
    yield* _statusController.stream;
  }

  void _setStatus(SyncStatus next) {
    if (_disposed || next == _status) return;
    _status = next;
    _statusController.add(next);
  }

  /// Recharge les compteurs (file + dead-letter) dans le statut, en fixant
  /// optionnellement la [phase].
  Future<void> _refreshCounts({SyncPhase? phase}) async {
    final pending = (await _queue.readAll()).length;
    final rejected = await _rejectedStore.count();
    _setStatus(SyncStatus(
      phase: phase ?? _status.phase,
      pending: pending,
      rejected: rejected,
    ));
  }

  void start() {
    if (!enabled || _subscription != null || _disposed) return;
    _subscription = _connectivity.watch().listen((online) {
      if (online) {
        unawaited(syncNow());
      } else {
        _setStatus(_status.copyWith(phase: SyncPhase.offline));
      }
    });
  }

  /// Réinitialise l'état local et le repeuple depuis le serveur, pris comme
  /// **source de vérité** : vide la file en attente, la dead-letter, le store
  /// local et le curseur de synchro, puis tire tout l'état serveur (pull
  /// complet).
  ///
  /// Appelé au login pour repartir propre (changement de compte, écritures
  /// optimistes obsolètes, store hérité d'une session précédente). No-op en
  /// mode local-only : le store local y est l'unique source, rien à rapatrier.
  Future<void> resetToRemote() async {
    if (!enabled || _disposed) return;
    await _lock.synchronized(() async {
      await _queue.clear();
      await _rejectedStore.clear();
      await _cursor.clear();
      await _store.clear();
    });
    _logger?.info('sync.reset');
    await _refreshCounts();
    await syncNow();
  }

  /// Push (drain de la file) puis pull (delta). Best-effort : une erreur réseau
  /// laisse la file intacte et sera réessayée au prochain passage en ligne.
  Future<void> syncNow() async {
    if (!enabled || _disposed) return;
    if (!_connectivity.isOnline) {
      _setStatus(_status.copyWith(phase: SyncPhase.offline));
      return;
    }
    await _lock.synchronized(() async {
      _setStatus(_status.copyWith(phase: SyncPhase.syncing));
      final sw = Stopwatch()..start();
      try {
        final push = await _push();
        final pulled = await _pull();
        await _refreshCounts(phase: SyncPhase.idle);
        // On ne logge que les synchros « utiles » : un drain à vide à chaque
        // bascule réseau ne doit pas inonder Signoz.
        if (push.sent > 0 || pulled > 0) {
          _logger?.info('sync.completed', attrs: {
            'sync.pushed': push.sent,
            'sync.rejected': push.rejected,
            'sync.pulled': pulled,
            'sync.duration_ms': sw.elapsedMilliseconds,
          });
        }
      } catch (e, st) {
        // Best-effort : la file reste intacte, réessai au prochain passage en ligne.
        await _refreshCounts(phase: SyncPhase.error);
        _logger?.error('sync.failed', error: e, stack: st);
      }
    });
  }

  /// Réinjecte les écritures en dead-letter dans la file et relance une synchro.
  /// Utile après un correctif serveur (un `invalid` d'hier peut passer
  /// aujourd'hui) ; un rejet toujours valable repartira en dead-letter.
  Future<void> retryRejected() async {
    if (!enabled || _disposed) return;
    await _lock.synchronized(() async {
      final ops = await _rejectedStore.readAll();
      for (final op in ops) {
        await _queue.enqueue(op.resource, op.entityId, op.data);
      }
      await _rejectedStore.clear();
    });
    await _refreshCounts();
    await syncNow();
  }

  /// Abandonne définitivement les écritures en dead-letter (l'utilisateur
  /// renonce à les synchroniser).
  Future<void> discardRejected() async {
    if (_disposed) return;
    await _rejectedStore.clear();
    await _refreshCounts();
  }

  /// Draine la file (push). Renvoie le nombre d'ops envoyées et le nombre
  /// refusées (routées en dead-letter).
  Future<({int sent, int rejected})> _push() async {
    final ops = await _queue.readAll();
    if (ops.isEmpty) return (sent: 0, rejected: 0);
    final changes = <String, List<Map<String, dynamic>>>{};
    for (final op in ops) {
      changes.putIfAbsent(op.resource, () => []).add(op.data);
    }
    final result = await _api.push(changes); // lève → file préservée
    final reasonByKey = {
      for (final r in result.rejected) '${r.resource}/${r.id}': r.reason,
    };
    final deadLetters = <RejectedOp>[];
    for (final op in ops) {
      final reason = reasonByKey['${op.resource}/${op.entityId}'];
      if (reason != null) {
        deadLetters.add(RejectedOp(
          resource: op.resource,
          entityId: op.entityId,
          data: op.data,
          reason: reason,
        ));
      }
      // Appliquée ou refusée : dans les deux cas l'op a été traitée par le
      // serveur, on la retire de la file (les refus sont conservés en
      // dead-letter ci-dessous).
      await _queue.remove(op.resource, op.entityId);
    }
    if (deadLetters.isNotEmpty) {
      await _rejectedStore.addAll(deadLetters);
      _logger?.warn('sync.push.rejected', attrs: {'sync.rejected': deadLetters.length});
    }
    return (sent: ops.length, rejected: deadLetters.length);
  }

  /// Tire les changements delta. Renvoie le nombre de lignes appliquées au store.
  Future<int> _pull() async {
    final since = await _cursor.read();
    final result = await _api.pull(since);
    var count = 0;
    for (final entry in result.changes.entries) {
      await _store.upsertAll(entry.key, entry.value);
      count += entry.value.length;
    }
    await _cursor.write(result.serverTime);
    return count;
  }

  Future<void> dispose() async {
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    await _statusController.close();
  }
}
