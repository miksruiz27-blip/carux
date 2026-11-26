# Práctica de Física: MRU · Equipo 4 · ITS Saltillo

App web interactiva sobre Movimiento Rectilíneo Uniforme. Contexto y reglas en [CLAUDE.md](CLAUDE.md).

## App (Flutter Web)

```bash
cd app
flutter pub get
flutter run -d chrome       # desarrollo
flutter test                # tests de lógica
flutter build web           # genera app/build/web
```

## Server (Node 20 + Express + Postgres)

```bash
cd server
npm install
DATABASE_URL=postgres://... npm start
```

En producción (Railway) el server sirve `app/build/web` como estáticos y la API en `/api`.
