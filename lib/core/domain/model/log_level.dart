/// Sévérité d'un enregistrement de log.
///
/// Calquée sur l'échelle OpenTelemetry `SeverityNumber` utilisée par Signoz,
/// pour que l'adaptateur d'infra n'ait pas à inventer sa propre traduction :
///
/// | Niveau | severityNumber OTel | severityText OTel |
/// |--------|--------------------:|-------------------|
/// | debug  | 5                   | DEBUG             |
/// | info   | 9                   | INFO              |
/// | warn   | 13                  | WARN              |
/// | error  | 17                  | ERROR             |
///
/// Volontairement court — Motorz n'a pas besoin de la granularité
/// `trace`/`fatal`, et ajouter des niveaux plus tard reste non cassant.
enum LogLevel {
  debug(5, 'DEBUG'),
  info(9, 'INFO'),
  warn(13, 'WARN'),
  error(17, 'ERROR');

  const LogLevel(this.otelSeverityNumber, this.otelSeverityText);

  /// Sévérité numérique OpenTelemetry. Utilisée par l'exporteur OTLP.
  final int otelSeverityNumber;

  /// Sévérité textuelle OpenTelemetry. Affichée telle quelle dans Signoz.
  final String otelSeverityText;
}
