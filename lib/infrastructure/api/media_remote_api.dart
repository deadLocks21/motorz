import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Upload/suppression de médias (binaires) via REST — en ligne uniquement.
/// Le proxy `/media/:id` sert ensuite les octets (authentifié).
class MediaRemoteApi {
  final Dio _dio;
  MediaRemoteApi(this._dio);

  /// Uploade un fichier et renvoie la ligne média créée (métadonnées).
  Future<Map<String, dynamic>> upload({
    required String ownerType,
    required String ownerId,
    required String kind,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final form = FormData.fromMap({
      'owner_type': ownerType,
      'owner_id': ownerId,
      'kind': kind,
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final res = await _dio.post<Map<String, dynamic>>('/media', data: form);
    return res.data!;
  }

  Future<void> delete(String id) async {
    await _dio.delete<void>('/media/$id');
  }
}
