# motorz-app

Application **Motorz** — Flutter (Android · iOS · macOS · Windows · Linux · Web).

Spécifications : dépôt de documentation `motorz` (`BRIEF.md`). Identité visuelle « Motorsport » : voir `design/` (tokens `AppColors` dans `design/app_colors.dart`, icône `design/motorz-icon.svg`).

Conventions reprises de `songbook-app` / `kidflix` : archi **hexagonale layer-first** (`core/domain`, `core/application`, `infrastructure`, `ui`), Riverpod 3 + codegen, modèles écrits à la main, `go_router`, `dio`, **offline-first** (sqflite + file d'attente + sync), imports absolus, `InMemory*` en test.

## Observabilité (Signoz)

Les logs applicatifs sont expédiés vers **Signoz** en OTLP/HTTP (`/v1/logs`), sur le modèle de `songbook-app` / `kidflix`. Pipeline : `LoggerService` (port domaine, `core/domain/services/`) → `SignozLoggerService` (OTLP/HTTP, mise en lot best-effort) + `ConsoleLoggerService`, exposés via `loggerProvider` (`infrastructure/providers/logger_providers.dart`). Les erreurs Flutter/Dart non capturées et les transitions de cycle de vie (`app.started` / `app.paused` → flush) sont déjà câblées dans `main.dart`. Aucune dépendance nouvelle : tout repose sur `dio` + `uuid` déjà présents.

Activé **à la compilation** par `--dart-define`. Sans `SIGNOZ_INGEST_URL`, l'app retombe sur la console seule (aucun trafic réseau) :

| Define                 | Rôle |
|------------------------|------|
| `SIGNOZ_INGEST_URL`    | Endpoint OTLP logs, ex. `https://ingest.eu.signoz.cloud:443/v1/logs`. Vide → Signoz désactivé. |
| `SIGNOZ_INGESTION_KEY` | Clé Signoz Cloud (en-tête `signoz-access-token`). Vide pour un self-hosted sans auth. |
| `SIGNOZ_ENV`           | Surcharge `deployment.environment` (défaut : `production` en release, `development` sinon). |
| `APP_VERSION`          | `service.version` (le CI injecte `$VERSION+$BUILD_NUMBER` ; défaut `dev`). |

```bash
# Dev — émulateur Android → collecteur self-hosted sur l'hôte
flutter run --dart-define=SIGNOZ_INGEST_URL=http://10.0.2.2:4318/v1/logs

# Release → Signoz Cloud
flutter build appbundle --release \
  --dart-define=SIGNOZ_INGEST_URL=https://ingest.eu.signoz.cloud:443/v1/logs \
  --dart-define=SIGNOZ_INGESTION_KEY="$SIGNOZ_INGESTION_KEY" \
  --dart-define=APP_VERSION="$VERSION+$BUILD_NUMBER"
```

En build **debug** avec `SIGNOZ_INGEST_URL` défini, les logs sont *aussi* reflétés dans la console (préfixe `[→signoz]`) pour calibrage. Attributs joints à chaque ligne : `session.id` (un par lancement), puis `device.id` (= en-tête `X-Device-Id`, recoupe les logs backend) et `user.id` une fois connecté.

> CI : l'app sera buildée par **GitHub Actions** (BRIEF §12). Injecter `SIGNOZ_INGEST_URL` / `SIGNOZ_INGESTION_KEY` via les *secrets* du dépôt et les passer en `--dart-define` à l'étape `flutter build` (modèle : `songbook-app/.github/workflows/release.yml`).

> Statut : front implémenté (features §5), offline-first + auth OTP câblés. Observabilité Signoz en place ; instrumentation métier (synchro, auth, usecases) à enrichir au fil de l'eau.
