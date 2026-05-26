import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, kReleaseMode;
import 'package:motorz/core/application/services/logger_application.service.dart';
import 'package:motorz/core/domain/model/uuid_value.dart';
import 'package:motorz/core/domain/services/logger.service.dart';
import 'package:motorz/infrastructure/logger/composite.logger.service.dart';
import 'package:motorz/infrastructure/logger/console.logger.service.dart';
import 'package:motorz/infrastructure/logger/signoz.logger.service.dart';
import 'package:motorz/infrastructure/providers/session_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'logger_providers.g.dart';

/// Endpoint OTLP HTTP Signoz, fixé à la compilation, ex.
/// `https://ingest.eu.signoz.cloud:443/v1/logs`. Vide → Signoz désactivé.
///
/// À passer via :
/// `flutter run --dart-define=SIGNOZ_INGEST_URL=https://…/v1/logs`
const String _kSignozEndpoint = String.fromEnvironment('SIGNOZ_INGEST_URL');

/// Clé d'ingestion Signoz Cloud, fixée à la compilation. Envoyée comme
/// `signoz-access-token`. Laisser vide pour un self-hosted sans auth.
const String _kSignozKey = String.fromEnvironment('SIGNOZ_INGESTION_KEY');

/// Surcharge optionnelle de l'attribut de ressource `deployment.environment`.
/// Par défaut `production` en release, `development` sinon.
const String _kEnvOverride = String.fromEnvironment('SIGNOZ_ENV');

/// Version de l'app exposée comme attribut de ressource `service.version`.
/// Le build CI peut injecter la vraie valeur via
/// `--dart-define=APP_VERSION=$VERSION+$BUILD_NUMBER`. Par défaut une sentinelle
/// pour que les builds locaux non configurés soient évidents dans Signoz.
const String _kAppVersion = String.fromEnvironment(
  'APP_VERSION',
  defaultValue: 'dev',
);

/// [LoggerService] unique pour toute l'app.
///
/// Logique de sélection :
///
/// | Mode    | SIGNOZ_INGEST_URL défini | Implémentation                         |
/// |---------|--------------------------|----------------------------------------|
/// | release | non                      | [ConsoleLoggerService] (fail-safe)     |
/// | release | oui                      | [SignozLoggerService] seul             |
/// | debug   | non                      | [ConsoleLoggerService] seul            |
/// | debug   | oui                      | [CompositeLoggerService] : console+signoz|
///
/// La branche debug+signoz est ce qui permet au dev de voir dans sa propre
/// console exactement ce qui est expédié — cf. la discussion « calibrage »
/// dans la doc de [LoggerService].
///
/// `keepAlive` car l'adaptateur Signoz sous-jacent tient un timer périodique +
/// un client dio qu'il serait gâché de monter/démonter à la demande.
@Riverpod(keepAlive: true)
LoggerService loggerService(Ref ref) {
  final hasSignoz = _kSignozEndpoint.isNotEmpty;

  final console = ConsoleLoggerService(
    prefix: hasSignoz && !kReleaseMode ? '[→signoz]' : null,
  );

  if (!hasSignoz) {
    return console;
  }

  final signoz = SignozLoggerService(
    endpoint: _kSignozEndpoint,
    ingestionKey: _kSignozKey.isEmpty ? null : _kSignozKey,
    resourceAttributes: _resourceAttributes(),
  );
  ref.onDispose(signoz.dispose);

  if (kReleaseMode) {
    return signoz;
  }
  // Build debug avec Signoz câblé : reflète dans la console pour le calibrage.
  return CompositeLoggerService([console, signoz]);
}

/// Façade ergonomique consommée par les usecases / l'UI / `main.dart`.
///
/// Le résolveur de contexte dynamique lit [currentSessionProvider] via
/// `ref.read` — **pas** `ref.watch` — à chaque émission. Deux conséquences :
///
/// - L'instance de logger reste stable au fil des connexions/déconnexions.
///   La reconstruire à chaque transition de session démonterait le tampon de
///   lot Signoz et perdrait les enregistrements en vol.
/// - Chaque enregistrement émis porte l'identité **courante** : un log émis
///   juste après `verifyOtp` a déjà le `device.id` / `user.id`.
///
/// Attributs expédiés à Signoz, le cas échéant :
///
/// | Clé          | Source                          | Présent quand           |
/// |--------------|---------------------------------|-------------------------|
/// | `session.id` | UUID par lancement d'app        | toujours                |
/// | `device.id`  | `Session.device.id`             | une fois authentifié    |
/// | `user.id`    | `Session.user.id`               | une fois authentifié    |
///
/// `device.id` est le même que l'en-tête HTTP `X-Device-Id` (cf.
/// `AuthInterceptor`), donc les logs backend et Signoz se recoupent dessus.
/// `session.id` est le seul identifiant disponible avant connexion (écrans
/// téléphone/OTP) et corrèle toutes les lignes d'une même exécution.
///
/// `service.version`, `os.type`, `deployment.environment` sont attachés une
/// fois par lot comme attributs de *ressource* OTLP (cf. [loggerService]).
///
/// `keepAlive` pour que le tampon de lot Signoz survive à toute la durée de
/// vie de l'app plutôt que d'être démonté à la disposition du provider.
@Riverpod(keepAlive: true)
LoggerApplicationService logger(Ref ref) {
  // Un identifiant par lancement d'app. Le provider étant `keepAlive` et sans
  // dépendance dynamique, il n'est construit qu'une fois → l'id reste stable.
  final sessionId = UuidValue.generate().value;
  return LoggerApplicationService(
    ref.watch(loggerServiceProvider),
    resolveContext: () {
      final session = ref.read(currentSessionProvider);
      return <String, Object?>{
        'session.id': sessionId,
        if (session != null) 'device.id': session.device.id,
        if (session != null) 'user.id': session.user.id.value,
      };
    },
  );
}

Map<String, Object?> _resourceAttributes() {
  String env;
  if (_kEnvOverride.isNotEmpty) {
    env = _kEnvOverride;
  } else {
    env = kReleaseMode ? 'production' : 'development';
  }
  return {
    'service.name': 'motorz',
    'service.version': _kAppVersion,
    'deployment.environment': env,
    'os.type': _osType(),
    'container.name': 'motorz-flutter',
    'host.name': 'fr.dtfh.motorz',
  };
}

String _osType() {
  // `defaultTargetPlatform` est web-safe (contrairement à `dart:io`/`Platform`)
  // et renvoie les mêmes libellés que `Platform.operatingSystem`.
  if (kIsWeb) return 'web';
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android',
    TargetPlatform.iOS => 'ios',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}
