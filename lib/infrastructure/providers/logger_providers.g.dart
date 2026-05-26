// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'logger_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
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

@ProviderFor(loggerService)
final loggerServiceProvider = LoggerServiceProvider._();

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

final class LoggerServiceProvider
    extends $FunctionalProvider<LoggerService, LoggerService, LoggerService>
    with $Provider<LoggerService> {
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
  LoggerServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loggerServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loggerServiceHash();

  @$internal
  @override
  $ProviderElement<LoggerService> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  LoggerService create(Ref ref) {
    return loggerService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoggerService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoggerService>(value),
    );
  }
}

String _$loggerServiceHash() => r'd4776e190e5d6bf22bee8a513efc6e7be48c7fbd';

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

@ProviderFor(logger)
final loggerProvider = LoggerProvider._();

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

final class LoggerProvider
    extends
        $FunctionalProvider<
          LoggerApplicationService,
          LoggerApplicationService,
          LoggerApplicationService
        >
    with $Provider<LoggerApplicationService> {
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
  LoggerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'loggerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$loggerHash();

  @$internal
  @override
  $ProviderElement<LoggerApplicationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LoggerApplicationService create(Ref ref) {
    return logger(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LoggerApplicationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LoggerApplicationService>(value),
    );
  }
}

String _$loggerHash() => r'ffd6c15848a87cc284eeff0f347e3524f96dedfe';
