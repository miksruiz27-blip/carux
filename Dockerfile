# syntax=docker/dockerfile:1

# ── Etapa 1: build de Flutter Web ────────────────────────────────────────
# Flutter fijado a la misma versión que se usa en desarrollo (pubspec pide Dart ^3.13.2).
# ponytail: se clona Flutter en vez de ghcr.io/cirruslabs/flutter:stable porque esa imagen
# va atrasada (3.44, Dart 3.12) y el build fallaría. Si se pone al día, se puede cambiar.
FROM debian:bookworm-slim AS web
ARG FLUTTER_VERSION=3.47.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends git curl unzip xz-utils ca-certificates \
 && rm -rf /var/lib/apt/lists/*
RUN git clone --depth 1 --branch "$FLUTTER_VERSION" https://github.com/flutter/flutter.git /flutter
ENV PATH=/flutter/bin:$PATH
RUN flutter config --no-analytics --enable-web && flutter precache --web

WORKDIR /src/app
COPY app/pubspec.yaml app/pubspec.lock ./
RUN flutter pub get
COPY app/ ./
RUN flutter build web --release

# ── Etapa 2: servidor Node ───────────────────────────────────────────────
FROM node:20-slim
ENV NODE_ENV=production PORT=3000
# Misma estructura que el repo: el server busca ../app/build/web por defecto.
WORKDIR /srv/server
COPY server/package.json server/package-lock.json ./
RUN npm ci --omit=dev
COPY server/ ./
COPY --from=web /src/app/build/web /srv/app/build/web
USER node
EXPOSE 3000
CMD ["node", "index.js"]
