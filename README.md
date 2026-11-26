# Práctica de Física: MRU · Equipo 4 · ITS Saltillo

App web interactiva sobre Movimiento Rectilíneo Uniforme. Contexto y reglas en [CLAUDE.md](CLAUDE.md).

## App (Flutter Web)

```bash
cd app
flutter pub get
flutter run -d chrome       # desarrollo
# contra el server local (que necesita CORS_ORIGIN=http://localhost:5000):
flutter run -d chrome --web-port 5000 --dart-define=API_BASE=http://localhost:3000/api
flutter test                # tests de lógica
flutter build web           # genera app/build/web
```

## Server (Node 20 + Express + Postgres)

```bash
cd server
npm install
DATABASE_URL=postgres://... ADMIN_PIN=... npm start   # PORT y STATIC_DIR opcionales
TEST_DATABASE_URL=postgres://.../mru_test npm test     # sin la variable solo corren los tests de puntaje
```

En producción (Railway) el server sirve `app/build/web` como estáticos y la API en `/api`.

## Despliegue en Railway

Un solo servicio (el `Dockerfile` de la raíz compila Flutter Web y arranca Node) más una base Postgres.
`railway.json` ya le dice a Railway que use el Dockerfile y que revise `/api/health`.

0. Sube todo a GitHub (`git push`). Railway construye desde el repo.
1. En [railway.com](https://railway.com) → **New Project** → **Deploy from GitHub repo** → elige este repo.
   Railway detecta `railway.json` y empieza a construir. El primer build tarda unos 5–10 min
   (descarga Flutter); puede fallar mientras no existan las variables del paso 3, es normal.
2. En el lienzo del proyecto: **+ Create** → **Database** → **PostgreSQL**. Debe quedar con el nombre `Postgres`.
3. Abre el servicio de la app → pestaña **Variables** → agrega:
   | Variable | Valor |
   |---|---|
   | `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` (escríbelo tal cual; Railway lo sustituye) |
   | `ADMIN_PIN` | un PIN que solo sepa el equipo (sin él, "Reiniciar tabla" queda deshabilitado) |
   | `PORT` | `3000` |

   Al guardar, Railway vuelve a desplegar. Las tablas se crean solas al arrancar.
4. En el servicio de la app → **Settings** → **Networking** → **Generate Domain** → puerto `3000`.
   Te da una URL tipo `https://carux-production.up.railway.app`.
5. Comprueba: `https://<tu-dominio>/api/health` debe responder `{"ok":true}`.
6. QR para imprimir o proyectar:
   ```bash
   cd server && npm install && npm run qr -- https://<tu-dominio>
   ```
   Queda en `docs/qr.png`.

Para reiniciar el marcador antes de la presentación: candado al pie del marcador → PIN.

