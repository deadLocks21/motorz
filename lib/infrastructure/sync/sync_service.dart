import 'dart:async';

import 'package:motorz/core/application/services/logger_application.service.dart';
import 'package:motorz/core/domain/services/connectivity.service.dart';
import 'package:motorz/infrastructure/sync/local_record_store.dart';
import 'package:motorz/infrastructure/sync/pending_queue.dart';
import 'package:motorz/infrastructure/sync/sync_api.dart';
import 'package:motorz/infrastructure/sync/sync_cursor.dart';
import 'package:synchronized/synchronized.dart';

/// Service de synchro offline-first : à chaque retour en ligne (et une fois au
/// démarrage si en ligne), pousse la file (FIFO) puis tire les changements
/// delta dans le store local. Sérialisé par un [Lock].
class SyncService {
  final SyncApi _api;
  final LocalRecordStore _store;
  final PendingQueue _queue;
  final ConnectivityService _connectivity;
  final SyncCursorStore _cursor;
  final LoggerApplicationService? _logger;

  /// `false` en mode local-only (pas de backend configuré) : la synchro est
  /// neutralisée, le store local reste pleinement fonctionnel.
  final bool enabled;

  StreamSubscription<bool>? _subscription;
  final Lock _lock = Lock();
  bool _disposed = false;

  SyncService({
    required SyncApi api,
    required LocalRecordStore store,
    required PendingQueue queue,
    required ConnectivityService connectivity,
    required SyncCursorStore cursor,
    LoggerApplicationService? logger,
    this.enabled = true,
  })  : _api = api,
        _store = store,
        _queue = queue,
        _connectivity = connectivity,
        _cursor = cursor,
        _logger = logger;

  void start() {
    if (!enabled || _subscription != null || _disposed) return;
    _subscription = _connectivity.watch().listen((online) {
      if (online) unawaited(syncNow());
    });
  }

  /// Réinitialise l'état local et le repeuple depuis le serveur, pris comme
  /// **source de vérité** : vide la file en attente, le store local et le
  /// curseur de synchro, puis tire tout l'état serveur (pull complet).
  ///
  /// Appelé au login pour repartir propre (changement de compte, écritures
  /// optimistes obsolètes, store hérité d'une session précédente). No-op en
  /// mode local-only : le store local y est l'unique source, rien à rapatrier.
  Future<void> resetToRemote() async {
    if (!enabled || _disposed) return;
    await _lock.synchronized(() async {
      await _queue.clear();
      await _cursor.clear();
      await _store.clear();
    });
    _logger?.info('sync.reset');
    await syncNow();
  }

  /// Push (drain de la file) puis pull (delta). Best-effort : une erreur réseau
  /// laisse la file intacte et sera réessayée au prochain passage en ligne.
  Future<void> syncNow() async {
    if (!enabled || _disposed || !_connectivity.isOnline) return;
    await _lock.synchronized(() async {
      final sw = Stopwatch()..start();
      try {
        final pushed = await _push();
        final pulled = await _pull();
        // On ne logge que les synchros « utiles » : un drain à vide à chaque
        // bascule réseau ne doit pas inonder Signoz.
        if (pushed > 0 || pulled > 0) {
          _logger?.info('sync.completed', attrs: {
            'sync.pushed': pushed,
            'sync.pulled': pulled,
            'sync.duration_ms': sw.elapsedMilliseconds,
          });
        }
      } catch (e, st) {
        // Best-effort : la file reste intacte, réessai au prochain passage en ligne.
        _logger?.error('sync.failed', error: e, stack: st);
      }
    });
  }

  /// Draine la file (push). Renvoie le nombre d'opérations poussées.
  Future<int> _push() async {
    final ops = await _queue.readAll();
    if (ops.isEmpty) return 0;
    final changes = <String, List<Map<String, dynamic>>>{};
    for (final op in ops) {
      changes.putIfAbsent(op.resource, () => []).add(op.data);
    }
    await _api.push(changes); // lève → file préservée
    for (final op in ops) {
      await _queue.remove(op.resource, op.entityId);
    }
    return ops.length;
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
  }
}
