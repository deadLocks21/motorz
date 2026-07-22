import 'package:dio/dio.dart';
import 'package:motorz/core/application/services/logger_application.service.dart';

/// Trace chaque échange HTTP : une ligne au départ, une à l'arrivée, une en cas
/// d'échec.
///
/// C'est la seule fenêtre sur la couche transport. `/auth/*` et `/sync/*`
/// passent par Dio sans autre journalisation : un « Pas de connexion au
/// serveur » à l'écran ne laissait jusqu'ici aucune trace exploitable — ni
/// l'URL réellement appelée, ni le code HTTP, ni la cause système. Les logs
/// métier existants (`auth.otp.request_failed`, `sync.failed`) ne portent que
/// le verdict déjà traduit, pas de quoi remonter à sa cause.
///
/// ## Ce qui est journalisé — et ce qui ne l'est pas
///
/// Les **corps de requête ne sont jamais journalisés** : ils portent le code
/// OTP, le code de partage d'un véhicule et toutes les données métier poussées
/// en synchro. Seuls la méthode, l'URL et les métadonnées de réponse sortent.
///
/// Le corps de *réponse* n'est repris ([_bodyPreview]) que s'il n'est **pas**
/// du JSON — donc jamais une charge métier, que Dio a déjà désérialisée en
/// `Map`/`List`. C'est précisément le cas qui compte pour le diagnostic : une
/// URL d'API mal réglée ne produit pas une erreur réseau mais du HTML (page
/// d'erreur nginx, ou SPA servie en catch-all avec un franc 200). Voir
/// `<html><head><title>405 Not Allowed` dans les logs tranche en une seconde
/// ce qu'un code d'erreur générique laisse deviner pendant une heure.
///
/// ## Niveaux
///
/// Départ et succès en `debug` (une ligne par requête, l'app en fait peu :
/// auth, synchro, médias) ; 4xx en `warn` — un refus attendu (OTP invalide,
/// compte inconnu) n'est pas une panne ; 5xx et échecs de transport en
/// `error`.
///
/// L'exporteur Signoz possède son propre client Dio, cet interceptor ne le
/// voit donc pas : aucune boucle log → requête → log.
class HttpLogInterceptor extends Interceptor {
  final LoggerApplicationService? _logger;

  HttpLogInterceptor({LoggerApplicationService? logger}) : _logger = logger;

  /// Chronomètre déposé dans `RequestOptions.extra` à l'aller, relu au retour :
  /// c'est le seul état partagé entre les deux callbacks, et il suit la requête
  /// même quand plusieurs sont en vol.
  static const _stopwatchKey = 'motorz.http.stopwatch';

  /// Longueur max d'un extrait de corps de réponse. Assez pour reconnaître une
  /// page d'erreur ou un `<!DOCTYPE html>`, trop court pour faire du volume.
  static const _previewLength = 180;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_stopwatchKey] = Stopwatch()..start();
    _logger?.debug('http.request', attrs: {
      'http.request.method': options.method,
      'url.full': _url(options),
    });
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _logger?.debug('http.response', attrs: {
      ..._exchangeAttrs(response.requestOptions),
      'http.response.status_code': response.statusCode,
      ..._responseShapeAttrs(response),
    });
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final status = err.response?.statusCode;
    final attrs = <String, Object?>{
      ..._exchangeAttrs(err.requestOptions),
      'http.response.status_code': ?status,
      // Le type Dio dit *où* ça a cassé (`connectionError`, `badResponse`,
      // `receiveTimeout`…), la cause dit *pourquoi* : `SocketException` (DNS,
      // hôte injoignable), `HandshakeException` (TLS), `ClientException`
      // (XMLHttpRequest bloqué côté navigateur — CORS, mixed content).
      'error.type': err.type.name,
      if (err.error != null) 'error.cause': err.error.runtimeType.toString(),
      if (err.error != null) 'error.message': _truncate(err.error.toString()),
      if (err.response != null) ..._responseShapeAttrs(err.response!),
    };

    // Transport en panne ou serveur en vrac : anomalie. 4xx : refus attendu.
    if (isTransportFailure(err.type) || (status != null && status >= 500)) {
      _logger?.error('http.failed', attrs: attrs, error: err.error ?? err);
    } else {
      _logger?.warn('http.failed', attrs: attrs);
    }
    handler.next(err);
  }

  Map<String, Object?> _exchangeAttrs(RequestOptions options) {
    final sw = options.extra[_stopwatchKey];
    return {
      'http.request.method': options.method,
      'url.full': _url(options),
      if (sw is Stopwatch) 'http.duration_ms': sw.elapsedMilliseconds,
    };
  }

  /// Content-type + extrait : de quoi reconnaître une réponse qui n'est pas
  /// celle de l'API.
  Map<String, Object?> _responseShapeAttrs(Response<dynamic> response) {
    final contentType = response.headers.value(Headers.contentTypeHeader);
    final preview = _bodyPreview(response, contentType);
    return {
      'http.response.content_type': ?contentType,
      'http.response.body_preview': ?preview,
    };
  }

  /// URL complète effectivement appelée (base + chemin résolus).
  ///
  /// `RequestOptions.uri` lève sur une base malformée — or une URL mal saisie
  /// est justement une cause d'échec plausible : on retombe alors sur la
  /// concaténation brute, qui reste la donnée la plus utile à lire.
  String _url(RequestOptions options) {
    try {
      return options.uri.toString();
    } catch (_) {
      return '${options.baseUrl}${options.path}';
    }
  }

  String? _bodyPreview(Response<dynamic> response, String? contentType) {
    // Réponse JSON : Dio l'a désérialisée en Map/List, c'est de la donnée
    // métier — hors de question de la recopier dans les logs.
    if (contentType != null && contentType.contains('json')) return null;
    final data = response.data;
    if (data is! String) return null;
    final flat = data.replaceAll(RegExp(r'\s+'), ' ').trim();
    return flat.isEmpty ? null : _truncate(flat);
  }

  String _truncate(String value) => value.length <= _previewLength
      ? value
      : '${value.substring(0, _previewLength)}…';
}

/// `true` si l'échange n'a jamais abouti à une réponse HTTP (DNS, TCP, TLS,
/// délais dépassés, XHR bloqué). Par opposition à `badResponse`, où le serveur
/// a bien répondu — avec un code d'erreur.
///
/// `unknown` en fait partie : c'est le fourre-tout de Dio pour les exceptions
/// non typées remontées de la couche socket, et sur le web c'est le type que
/// prend un `XMLHttpRequest error` (origine injoignable, CORS, mixed content).
bool isTransportFailure(DioExceptionType type) => switch (type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.badCertificate ||
      DioExceptionType.unknown =>
        true,
      DioExceptionType.badResponse || DioExceptionType.cancel => false,
    };
