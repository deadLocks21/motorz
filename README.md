# motorz-app

Application **Motorz** — Flutter (Android · iOS · macOS · Windows · Linux · Web).

Spécifications : dépôt de documentation `motorz` (`BRIEF.md`). Identité visuelle « Motorsport » : voir `design/` (tokens `AppColors` dans `design/app_colors.dart`, icône `design/motorz-icon.svg`).

Conventions reprises de `songbook-app` / `kidflix` : archi **hexagonale layer-first** (`core/domain`, `core/application`, `infrastructure`, `ui`), Riverpod 3 + codegen, modèles écrits à la main, `go_router`, `dio`, **offline-first** (sqflite + file d'attente + sync), imports absolus, `InMemory*` en test.

## Déploiement web (`motorz.dtfh.fr`)

Le client web est une **cible à part entière** : bundle Flutter web servi par nginx dans son propre conteneur (`Dockerfile` + `nginx.conf`), publié sur **Docker Hub** puis déployé par webhook docker-updater. Le backend garde sa chaîne GitLab.

Il est buildé **dans le même workflow que les binaires store** (`.github/workflows/release.yml`, déclenché sur tag `v*`), donc à partir du même commit, avec la même version et les mêmes `--dart-define` (Signoz inclus) : une version publiée désigne le même code sur tous les canaux. Jobs `build-web` (tags immuables `:X.Y.Z` et `:sha`) puis `publish-web` (promotion en `:latest` + déploiement), ce dernier conditionné au `build-gate`.

Découpage des URL sur l'hôte :

| Chemin             | Conteneur    | Remarque |
|--------------------|--------------|----------|
| `/`                | `motorz-web` | Le client web, catch-all. |
| `/api/*`           | `motorz-api` | **StripPrefix** : l'API continue de servir à la racine en interne. |
| `/privacy-policy`  | `motorz-api` | **Sans strip** — URL déclarée sur la fiche Google Play, à ne pas casser. |

⚠️ **Le web doit être servi sur le même domaine que l'API**, à un préfixe de chemin près. L'API n'expose aucun middleware CORS : un sous-domaine dédié (`app.motorz.dtfh.fr`) ferait échouer tous les appels réseau côté navigateur.

⚠️ Le web étant catch-all avec fallback SPA, **toute URL inconnue renvoie l'app en HTTP 200**, pas une 404. D'où le routeur dédié pour `/privacy-policy` : sans lui, Google recevrait silencieusement l'app à la place de la politique de confidentialité.

Deux valeurs sont **figées à la compilation** dans l'image (donc liée à un environnement), surchargeables en `--build-arg` :

| Build arg      | Défaut                        | Rôle |
|----------------|-------------------------------|------|
| `API_BASE_URL` | `https://motorz.dtfh.fr/api`  | `--dart-define` consommé par `infra_providers.dart`. `dio` préserve le préfixe de chemin. |
| `BASE_HREF`    | `/`                           | `--base-href` ; doit correspondre au chemin servi par nginx. |

`FLUTTER_VERSION`, `BUILD_NAME` / `BUILD_NUMBER` / `APP_VERSION` et les `SIGNOZ_*` sont également des build args, renseignés par `release.yml` pour coller aux builds store. Laissés vides — cas d'un build local — Flutter retombe sur `version:` de `pubspec.yaml` et l'app sur `ConsoleLoggerService`.

```bash
# Build + essai local (http://localhost:8080)
docker build --target runtime -t motorz-web:local .
docker run --rm -p 8080:80 motorz-web:local
```

Sur web, seule la **session** est persistée (`shared_preferences` → `localStorage`) ; le store local et le curseur de synchro restent en mémoire (cf. `infra_providers.dart`). Un rechargement de page conserve donc la connexion et re-synchronise l'état depuis le serveur (curseur nul = pull complet).

### Traefik

Récupérer d'abord les noms exacts d'entrypoint / certresolver / réseau utilisés par l'API :

```bash
docker inspect motorz-api --format '{{json .Config.Labels}}' | python3 -m json.tool
```

**Le conteneur `motorz-api` doit être recréé avec de nouveaux labels** : sa règle actuelle matche l'hôte entier et entrerait en conflit avec le catch-all du web. Elle se scinde en deux routeurs :

```bash
# motorz-api — remplace la règle Host(...) existante
-l 'traefik.http.routers.motorz-api.rule=Host(`motorz.dtfh.fr`) && PathPrefix(`/api`)'
-l 'traefik.http.routers.motorz-api.priority=100'
-l 'traefik.http.routers.motorz-api.service=motorz-api'
-l 'traefik.http.routers.motorz-api.middlewares=motorz-api-strip'
-l 'traefik.http.middlewares.motorz-api-strip.stripprefix.prefixes=/api'
# … et le routeur legal, sans strip, qui préserve l'URL du store
-l 'traefik.http.routers.motorz-legal.rule=Host(`motorz.dtfh.fr`) && PathPrefix(`/privacy-policy`)'
-l 'traefik.http.routers.motorz-legal.priority=100'
-l 'traefik.http.routers.motorz-legal.service=motorz-api'
-l 'traefik.http.services.motorz-api.loadbalancer.server.port=3000'  # = $PORT de l'API
```

Puis créer le conteneur web, en catch-all avec une priorité **basse** :

```bash
docker run -d --name motorz-web --restart unless-stopped \
  --network <réseau-traefik-de-l-api> \
  -l 'traefik.enable=true' \
  -l 'traefik.http.routers.motorz-web.rule=Host(`motorz.dtfh.fr`)' \
  -l 'traefik.http.routers.motorz-web.entrypoints=<idem API>' \
  -l 'traefik.http.routers.motorz-web.tls.certresolver=<idem API>' \
  -l 'traefik.http.routers.motorz-web.priority=1' \
  -l 'traefik.http.services.motorz-web.loadbalancer.server.port=80' \
  <DOCKERHUB_USERNAME>/motorz-web:latest
```

Les priorités sont explicites à dessein : sans elles Traefik départage par **longueur de règle**, ce qui donnerait le bon résultat mais de façon implicite et fragile. `priority=1` sur le web garantit qu'il ne prend que ce qu'aucun autre routeur ne réclame. `entrypoints` / `tls.certresolver` sont à reporter aussi sur les routeurs de l'API.

Après ces changements, vérifier les trois chemins :

```bash
curl -sI https://motorz.dtfh.fr/api/health      # 200, JSON de l'API
curl -sI https://motorz.dtfh.fr/privacy-policy  # 200, text/html de la politique
curl -sI https://motorz.dtfh.fr/                # 200, l'app
```

### Docker Hub & docker-updater

Enregistrer le conteneur **`motorz-web`** (et son token) dans `credentials.json` via `python app/cli.py`, comme pour l'API. L'image étant publique sur Docker Hub, aucun `docker login` n'est nécessaire sur le VPS.

Réglages GitHub (Settings → Secrets and variables → Actions) — détaillés en tête de `.github/workflows/release.yml` : variable `DOCKERHUB_USERNAME`, secrets `DOCKERHUB_TOKEN`, `DEPLOY_URL`, `DEPLOY_TOKEN`.

Le déploiement suit le cycle de release : tag `vX.Y.Z` poussé par semantic-release → miroir GitHub → `release.yml`. Pas de déploiement web hors release.

⚠️ Le bundle web étant servi en clair au navigateur, tout `--dart-define` qu'il embarque est **public** — `SIGNOZ_INGESTION_KEY` compris. C'est inhérent à une cible web, pas au choix d'une image Docker publique. Pour ne pas l'exposer, retirer la ligne `SIGNOZ_INGESTION_KEY=` des `build-args` de `build-web` : le web retombera sur `ConsoleLoggerService` sans rien changer aux binaires store.

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
