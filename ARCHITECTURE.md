# Architecture — motorz (Flutter)

Architecture **hexagonale, layer-first**, identique à `songbook-app` / `kidflix`.

## Dépendances

```
UI → Application → Domain ← Infrastructure
```

1. **Domain** (`lib/core/domain/`) ne dépend de personne — Dart pur.
   - ❌ Pas de Riverpod · ❌ pas de Flutter · ❌ pas d'HTTP. ✅ logique métier pure.
   - `model/` : entités (champs `final`, invariants par `assert`, `copyWith`/`==`/`hashCode`
     manuels), value objects (`UuidValue`), classes scellées + `switch` exhaustif
     (`SessionState`, `Resource`…).
   - `services/` : interfaces de ports (`*.repository.dart`, `*.service.dart`).
2. **Application** (`lib/core/application/`) ne dépend que de Domain — Dart pur.
   - `dtos/` : DTOs (`fromDomain`/`toDomain`/`fromJson`/`toJson`, dates ISO-8601, enums via
     `.name`). **L'UI ne manipule que des DTOs.**
   - `usecases/` : un cas d'usage = une classe `NameUseCase` (ports en dépendances).
   - `services/` : orchestration applicative.
3. **Infrastructure** (`lib/infrastructure/`) ne dépend que de Domain. **Seul lieu de Riverpod.**
   - Implémentations concrètes (`dio.*`, `sqflite.*`, `in_memory.*`, `secure_storage.*`).
   - `sync/` : store local sqflite (source de vérité), file d'attente FIFO, service de synchro.
   - `http/` : `AuthInterceptor` (Bearer + `X-Device-Id`).
   - `providers/` : providers Riverpod (`@riverpod`, `*.g.dart`) — assemblage des dépendances.
4. **UI** (`lib/ui/`) ne dépend que d'Application (et des interfaces Domain via providers).
   - `pages/<feature>/*.page.dart`, `widgets/*.widget.dart`, `providers/*.provider.dart`.
   - `router/` : go_router + `AppRoutes` + redirect piloté par `SessionState`.
   - `theme/` : `AppThemeData` + `MotorzPalette` + `AppColors` (ThemeExtension) + `context.appColors`.

## Règles

- **Imports absolus** (`package:motorz/...`), jamais de `../`.
- **Modèles écrits à la main** — pas de freezed/json_serializable. `build_runner` seulement pour
  le codegen Riverpod. Lint : `flutter_lints` + `riverpod_lint`.
- Chaque interface a une impl réelle **et** une impl `InMemory*` (tests + dev/web).
- **Tests** : miroir de `lib/` avec les `InMemory*` comme doublures (pas de mockito).

## Offline-first (cf. `infrastructure/sync/`)

- **Source de vérité locale** : `sqflite` (init FFI sur desktop). Toutes les **lectures** viennent
  du local.
- **Écriture** : d'abord le local (optimiste), puis push distant si en ligne, sinon mise en file.
- **File d'attente FIFO** persistante, **last-write-wins par `(resource, id)`**.
- **Service de synchro** : abonné à `connectivity_plus`, draine la file (FIFO, stop à la 1ʳᵉ
  erreur, sérialisé par un `Lock`) et tire les changements (`GET /sync/changes?since=`),
  applique upserts + tombstones (`deleted_at`).
- IDs = **UUID générés côté client** → création sans attendre le serveur, idempotence du push.
- Calculs dérivés (conso, km courant, états d'échéance) faits **localement**.

## Session & sécurité

- Machine d'états **`SessionState`** scellée (`Anonymous → OtpRequested → Registering →
  Authenticated`) pilotant `go_router` (redirect + `refreshListenable`).
- Session (`jwt`, `user`, `device_id`) persistée dans **`flutter_secure_storage`**.
- `API_BASE_URL` configurable au runtime (réglages) avec fallback `--dart-define`.
