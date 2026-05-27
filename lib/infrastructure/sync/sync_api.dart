import 'package:dio/dio.dart';

class PullResult {
  final String serverTime;
  final Map<String, List<Map<String, dynamic>>> changes;
  const PullResult({required this.serverTime, required this.changes});
}

/// Une ligne refusée par `/sync/push` (réponse 2xx, champ `rejected`) :
/// `forbidden` (cible non autorisée) ou `invalid` (payload invalide). Échec
/// **permanent** — la rejouer à l'identique serait re-rejetée.
class RejectedRow {
  final String resource;
  final String id;
  final String reason;
  const RejectedRow({required this.resource, required this.id, required this.reason});
}

/// Résultat d'un push : les lignes que le serveur a refusées (les autres sont
/// appliquées). Une réponse non-2xx lève à la place (échec transitoire).
class PushResult {
  final List<RejectedRow> rejected;
  const PushResult({required this.rejected});
}

/// Client HTTP des endpoints `/sync` (delta + push).
class SyncApi {
  final Dio _dio;
  SyncApi(this._dio);

  Future<PullResult> pull(String? since) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/sync/changes',
      queryParameters: since != null ? {'since': since} : null,
    );
    final data = res.data!;
    final rawChanges = (data['changes'] as Map).cast<String, dynamic>();
    final changes = <String, List<Map<String, dynamic>>>{};
    for (final entry in rawChanges.entries) {
      changes[entry.key] =
          (entry.value as List).map((e) => (e as Map).cast<String, dynamic>()).toList();
    }
    return PullResult(serverTime: data['server_time'] as String, changes: changes);
  }

  /// Pousse un lot de mutations. Lève en cas d'échec réseau/serveur (la file
  /// est préservée pour réessai). Sur 2xx, renvoie les lignes refusées
  /// (`rejected`) — échecs permanents à sortir de la file vers la dead-letter.
  Future<PushResult> push(Map<String, List<Map<String, dynamic>>> changes) async {
    final res = await _dio.post<Map<String, dynamic>>('/sync/push', data: {'changes': changes});
    final raw = (res.data?['rejected'] as List?) ?? const [];
    final rejected = raw.map((e) {
      final m = (e as Map).cast<String, dynamic>();
      return RejectedRow(
        resource: m['resource'] as String,
        id: m['id'] as String,
        reason: m['reason'] as String,
      );
    }).toList(growable: false);
    return PushResult(rejected: rejected);
  }
}
