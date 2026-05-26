import 'package:dio/dio.dart';

/// Appels REST véhicule en ligne (hors `/sync`) : rejoindre un véhicule partagé.
class VehicleRemoteApi {
  final Dio _dio;
  VehicleRemoteApi(this._dio);

  /// Rejoint un véhicule via son code de partage (crée l'accès côté serveur).
  /// Le véhicule remonte ensuite via `/sync/changes`.
  Future<void> join(String shareCode) async {
    await _dio.post<Map<String, dynamic>>('/vehicles/join', data: {'share_code': shareCode});
  }
}
