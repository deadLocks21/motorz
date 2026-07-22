import 'package:dio/dio.dart';
import 'package:motorz/core/application/services/logger_application.service.dart';
import 'package:motorz/infrastructure/http/http_log.interceptor.dart';

/// Ce qu'on trouve au bout d'une base d'API candidate.
enum ApiEndpointStatus {
  /// L'API Motorz répond bien ici.
  reachable,

  /// Quelqu'un répond, mais ce n'est pas l'API : page d'erreur d'un reverse
  /// proxy, client web servi en catch-all, autre service…
  notApi,

  /// Personne ne répond : DNS, TCP, TLS, délai dépassé.
  unreachable,
}

/// Verdict pour l'URL **telle qu'elle a été saisie**, et l'endroit où l'API
/// répond réellement s'il a pu être établi.
class ApiEndpointResolution {
  /// Ce que vaut l'URL saisie, prise au mot.
  final ApiEndpointStatus status;

  /// Base où l'API a effectivement répondu, `null` si nulle part. Différente
  /// de l'URL saisie quand le sondage a dû la corriger.
  final String? workingBaseUrl;

  const ApiEndpointResolution({required this.status, this.workingBaseUrl});

  /// `true` quand l'API est joignable, mais pas là où on la cherchait.
  bool get corrected => workingBaseUrl != null && status != ApiEndpointStatus.reachable;
}

/// Vérifie qu'une base d'API est bien servie par l'API Motorz — et, sinon,
/// tente de retrouver où elle se cache sur cet hôte.
///
/// Existe parce qu'une URL de backend fausse ne se voit pas : elle ne casse
/// qu'au premier appel réel, longtemps après avoir été saisie, sous les traits
/// d'une panne réseau. Sonder au moment du réglage rend la faute immédiate et,
/// le plus souvent, inutile à comprendre — voir [_pathCandidate].
///
/// **Client HTTP dédié, volontairement nu** : surtout pas celui de l'app, dont
/// l'`AuthInterceptor` attacherait le JWT de la session à une URL arbitraire
/// saisie à la main. Un sondage ne doit rien porter de sensible vers un hôte
/// qui n'a pas encore fait ses preuves. Délais courts : c'est une vérification
/// interactive, l'utilisateur attend devant.
class ApiEndpointProbe {
  final Dio _dio;
  final LoggerApplicationService? _logger;

  ApiEndpointProbe({Dio? dio, LoggerApplicationService? logger})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 5),
            )),
        _logger = logger {
    _dio.interceptors.add(HttpLogInterceptor(logger: logger));
  }

  /// Le préfixe sous lequel chercher l'API quand la base saisie répond sans
  /// être l'API. C'est le cas de figure réel : depuis que le client web occupe
  /// l'hôte en catch-all, l'API n'est plus servie qu'à `/api` (StripPrefix
  /// Traefik, cf. README). L'hôte nu reste ce que tout le monde tape.
  static const _pathCandidate = '/api';

  /// Route de santé de l'API — publique, sans effet de bord, et son corps
  /// suffit à l'identifier.
  static const _healthPath = '/health';

  /// Sonde une base précise, sans rien corriger.
  Future<ApiEndpointStatus> probe(String baseUrl) async {
    try {
      final res = await _dio.get<dynamic>('$baseUrl$_healthPath');
      // Un 200 ne prouve rien : un hôte qui sert une SPA en catch-all répond
      // 200 à *n'importe quelle* URL, avec du HTML. C'est la forme du corps qui
      // tranche — l'API répond `{"status":"ok"}`, que Dio désérialise en Map.
      return res.data is Map ? ApiEndpointStatus.reachable : ApiEndpointStatus.notApi;
    } on DioException catch (e) {
      return isTransportFailure(e.type)
          ? ApiEndpointStatus.unreachable
          : ApiEndpointStatus.notApi;
    }
  }

  /// Sonde [baseUrl], puis — si quelqu'un a répondu sans être l'API — regarde
  /// sous [_pathCandidate] avant de renoncer.
  ///
  /// Le second essai n'a lieu que sur un `notApi` : quand l'hôte est
  /// injoignable, chercher un sous-chemin ne ferait qu'attendre un deuxième
  /// délai pour le même échec.
  Future<ApiEndpointResolution> resolve(String baseUrl) async {
    final status = await probe(baseUrl);
    if (status == ApiEndpointStatus.reachable) {
      return ApiEndpointResolution(status: status, workingBaseUrl: baseUrl);
    }
    if (status == ApiEndpointStatus.notApi && !baseUrl.endsWith(_pathCandidate)) {
      final candidate = '$baseUrl$_pathCandidate';
      if (await probe(candidate) == ApiEndpointStatus.reachable) {
        _logger?.info('api.base_url.corrected', attrs: {'api.base_url': candidate});
        return ApiEndpointResolution(status: status, workingBaseUrl: candidate);
      }
    }
    _logger?.warn('api.base_url.unusable', attrs: {'api.probe.status': status.name});
    return ApiEndpointResolution(status: status);
  }
}
