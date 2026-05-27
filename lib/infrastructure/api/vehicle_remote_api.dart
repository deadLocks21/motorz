import 'package:dio/dio.dart';
import 'package:motorz/core/application/services/logger_application.service.dart';

/// Appels REST véhicule en ligne (hors `/sync`) : rejoindre un véhicule partagé.
class VehicleRemoteApi {
  final Dio _dio;
  final LoggerApplicationService? _logger;
  VehicleRemoteApi(this._dio, {LoggerApplicationService? logger}) : _logger = logger;

  /// Rejoint un véhicule via son code de partage (crée l'accès côté serveur).
  /// Le véhicule remonte ensuite via `/sync/changes`.
  Future<void> join(String shareCode) async {
    // NB : on ne logge jamais le code de partage (secret d'accès permanent).
    try {
      await _dio.post<Map<String, dynamic>>('/vehicles/join', data: {'share_code': shareCode});
      _logger?.info('vehicle.join.completed');
    } catch (e, st) {
      _logger?.warn('vehicle.join.failed', error: e, stack: st);
      rethrow;
    }
  }
}
