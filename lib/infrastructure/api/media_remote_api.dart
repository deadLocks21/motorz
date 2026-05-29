import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:motorz/core/application/services/logger_application.service.dart';

/// Upload/suppression de médias (binaires) via REST — en ligne uniquement.
/// Le proxy `/media/:id` sert ensuite les octets (authentifié).
class MediaRemoteApi {
  final Dio _dio;
  final LoggerApplicationService? _logger;
  MediaRemoteApi(this._dio, {LoggerApplicationService? logger}) : _logger = logger;

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
    try {
      final res = await _dio.post<Map<String, dynamic>>('/media', data: form);
      _logger?.info('media.upload.completed', attrs: {
        'media.owner_type': ownerType,
        'media.kind': kind,
        'media.bytes': bytes.length,
      });
      return res.data!;
    } catch (e, st) {
      _logger?.error('media.upload.failed',
          error: e,
          stack: st,
          attrs: {'media.owner_type': ownerType, 'media.kind': kind});
      rethrow;
    }
  }

  /// Télécharge les octets bruts d'un média via le proxy authentifié `/media/:id`.
  Future<Uint8List> download(String id) async {
    try {
      final res = await _dio.get<List<int>>(
        '/media/$id',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data!);
    } catch (e, st) {
      _logger?.error('media.download.failed', error: e, stack: st);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _dio.delete<void>('/media/$id');
    } catch (e, st) {
      _logger?.error('media.delete.failed', error: e, stack: st);
      rethrow;
    }
  }
}
