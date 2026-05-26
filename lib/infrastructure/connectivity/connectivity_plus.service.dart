import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:motorz/core/domain/services/connectivity.service.dart';

/// Implémentation `connectivity_plus`. Par défaut **en ligne** si le plugin
/// natif manque (hot-reload) ou en cas d'erreur — pour ne pas bloquer la saisie.
class ConnectivityPlusService implements ConnectivityService {
  final Connectivity _connectivity;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _online = true;

  ConnectivityPlusService({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    try {
      _subscription = _connectivity.onConnectivityChanged.listen(_handle, onError: (_) {});
    } on MissingPluginException {
      // pas de plugin natif → reste en ligne
    } catch (_) {}
    unawaited(_hydrate());
  }

  @override
  bool get isOnline => _online;

  @override
  Stream<bool> watch() async* {
    yield _online;
    yield* _controller.stream;
  }

  Future<void> _hydrate() async {
    try {
      _handle(await _connectivity.checkConnectivity());
    } catch (_) {}
  }

  void _handle(List<ConnectivityResult> results) {
    final next = results.any((r) => r != ConnectivityResult.none);
    if (next == _online) return;
    _online = next;
    if (!_controller.isClosed) _controller.add(next);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _controller.close();
  }
}

/// Toujours en ligne — pour tests/web.
class AlwaysOnlineConnectivityService implements ConnectivityService {
  const AlwaysOnlineConnectivityService();
  @override
  bool get isOnline => true;
  @override
  Stream<bool> watch() async* {
    yield true;
  }
}
