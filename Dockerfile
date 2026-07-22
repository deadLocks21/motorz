# syntax=docker/dockerfile:1.7
#
# Image du client web Motorz : bundle Flutter web servi par nginx à la racine
# de `motorz.dtfh.fr`, l'API étant exposée sous `/api` (StripPrefix Traefik).
#
# Le bundle est servi sur le **même domaine que l'API**, à un préfixe de chemin
# près : c'est ce qui évite toute configuration CORS côté API (elle n'expose
# aucun middleware CORS). Changer de sous-domaine casserait les appels réseau
# de l'app.

ARG FLUTTER_VERSION=3.41.7

# ---------- Stage 1: build du bundle web ----------
FROM ghcr.io/cirruslabs/flutter:${FLUTTER_VERSION} AS build
WORKDIR /src

# Figés à la compilation (`--dart-define` + `--base-href`) : l'image est donc
# liée à un environnement. Surchargeables via --build-arg.
ARG API_BASE_URL=https://motorz.dtfh.fr/api
ARG BASE_HREF=/

# Alignés sur les builds store (cf. .github/workflows/release.yml) : même
# version et mêmes `--dart-define`, pour que le web soit compilé dans les mêmes
# conditions que l'AAB et le .pkg. Vides par défaut → un `docker build` local
# retombe sur la version de pubspec.yaml et sur ConsoleLoggerService (aucune
# remontée Signoz).
ARG BUILD_NAME=
ARG BUILD_NUMBER=
ARG APP_VERSION=dev
ARG SIGNOZ_INGEST_URL=
ARG SIGNOZ_INGESTION_KEY=
ARG SIGNOZ_ENV=

# Couche de dépendances isolée : `pub get` n'est rejoué que si les manifestes
# bougent, pas à chaque changement de source.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
# `--build-name/-number` ne sont passés que s'ils sont fournis : sinon Flutter
# lit `version:` dans pubspec.yaml, ce qu'on veut pour un build local.
RUN set -eu; \
    EXTRA=""; \
    if [ -n "${BUILD_NAME}" ]; then EXTRA="${EXTRA} --build-name=${BUILD_NAME}"; fi; \
    if [ -n "${BUILD_NUMBER}" ]; then EXTRA="${EXTRA} --build-number=${BUILD_NUMBER}"; fi; \
    flutter build web --release \
      --base-href="${BASE_HREF}" \
      ${EXTRA} \
      --dart-define=API_BASE_URL="${API_BASE_URL}" \
      --dart-define=SIGNOZ_INGEST_URL="${SIGNOZ_INGEST_URL}" \
      --dart-define=SIGNOZ_INGESTION_KEY="${SIGNOZ_INGESTION_KEY}" \
      --dart-define=SIGNOZ_ENV="${SIGNOZ_ENV}" \
      --dart-define=APP_VERSION="${APP_VERSION}"

# ---------- Stage 2: runtime nginx ----------
FROM nginx:alpine AS runtime

ARG BUILD_VERSION=dev
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.title="motorz-web" \
      org.opencontainers.image.description="Client web Motorz — carnet de bord véhicules (Flutter web derrière nginx)" \
      org.opencontainers.image.licenses="UNLICENSED" \
      org.opencontainers.image.version="${BUILD_VERSION}" \
      org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}"

COPY nginx.conf /etc/nginx/conf.d/default.conf

# Servi à la racine : les URL demandées par le navigateur (/main.dart.js…)
# tombent directement sur le disque.
COPY --from=build /src/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost/healthz >/dev/null 2>&1 || exit 1
