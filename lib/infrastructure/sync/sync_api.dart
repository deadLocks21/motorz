import 'package:dio/dio.dart';

class PullResult {
  final String serverTime;
  final Map<String, List<Map<String, dynamic>>> changes;
  const PullResult({required this.serverTime, required this.changes});
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
  /// est préservée). Sur 2xx, les ops envoyées peuvent être retirées de la file
  /// (les `rejected` sont des échecs permanents : forbidden/invalid).
  Future<void> push(Map<String, List<Map<String, dynamic>>> changes) async {
    await _dio.post<Map<String, dynamic>>('/sync/push', data: {'changes': changes});
  }
}
