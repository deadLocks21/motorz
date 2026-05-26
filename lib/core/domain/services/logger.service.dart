import 'package:motorz/core/domain/model/log_level.dart';

/// Contrat d'émission des enregistrements de log.
///
/// Port domaine de la préoccupation « logging ». Les implémentations vivent
/// dans `lib/infrastructure/logger/` :
///
/// - `ConsoleLoggerService`   — écrit dans la console de dev.
/// - `SignozLoggerService`    — pousse les logs en OTLP/HTTP vers Signoz.
/// - `CompositeLoggerService` — diffuse vers plusieurs services à la fois
///   (utilisé pour refléter dans la console ce qui part vers Signoz pendant
///   le calibrage).
/// - `InMemoryLoggerService`  — capture les enregistrements pour les tests.
///
/// Le contrat est volontairement minuscule : un seul puits asynchrone. Les
/// commodités (`info`, `error`, attributs de contexte automatiques…) vivent
/// dans la couche application (`LoggerApplicationService`) pour que le port
/// reste stable d'une implémentation à l'autre.
///
/// `attributes` : paires clé/valeur libres attachées à l'enregistrement. Les
/// adaptateurs les sérialisent selon leur format cible (OTLP pour Signoz,
/// lignes `clé=valeur` pour la console…). Les valeurs doivent être des
/// primitives sérialisables JSON — `String`, `num`, `bool` ou `null`. Tout le
/// reste est converti via `toString()` par l'adaptateur.
///
/// Les implémentations NE DOIVENT PAS lever d'exception : un logger qui échoue
/// doit se dégrader silencieusement (le reste de l'app ne doit pas planter
/// parce que la télémétrie est indisponible).
abstract interface class LoggerService {
  /// Enregistre une entrée de log.
  ///
  /// [message] est le résumé lisible. À garder court et stable (bon :
  /// `sync.failed` ; mauvais : `Impossible de synchroniser xyz à 10:42`). Les
  /// données variables vont dans [attributes].
  ///
  /// [error] / [stack] sont optionnels et servent quand [level] vaut
  /// [LogLevel.error] (parfois [LogLevel.warn]) à capturer le type
  /// d'exception et la stacktrace en plus du message.
  Future<void> log(
    LogLevel level,
    String message, {
    Map<String, Object?> attributes,
    Object? error,
    StackTrace? stack,
  });

  /// Vide le tampon en cours. Appelé à la pause/destruction de l'app pour que
  /// les logs émis juste avant la mise en arrière-plan ne soient pas perdus.
  /// No-op pour les adaptateurs sans tampon.
  Future<void> flush();
}
