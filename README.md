# motorz-app

Application **Motorz** — Flutter (Android · iOS · macOS · Windows · Linux · Web).

Spécifications : dépôt de documentation `motorz` (`BRIEF.md`). Identité visuelle « Motorsport » : voir `design/` (tokens `AppColors` dans `design/app_colors.dart`, icône `design/motorz-icon.svg`).

Conventions reprises de `songbook-app` / `kidflix` : archi **hexagonale layer-first** (`core/domain`, `core/application`, `infrastructure`, `ui`), Riverpod 3 + codegen, modèles écrits à la main, `go_router`, `dio`, **offline-first** (sqflite + file d'attente + sync), imports absolus, `InMemory*` en test.

> Statut : dépôt initialisé, scaffolding à venir.
