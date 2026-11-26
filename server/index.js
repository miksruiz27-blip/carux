import path from 'node:path';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import { createApp, migrate } from './app.js';

if (!process.env.DATABASE_URL) {
  console.error('Falta DATABASE_URL');
  process.exit(1);
}
if (!process.env.ADMIN_PIN) console.warn('ADMIN_PIN no definido: el reinicio de la tabla queda deshabilitado');

const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
// Sin esto, un reinicio de Postgres tumba el proceso por un 'error' sin manejar en una conexión inactiva.
pool.on('error', (e) => console.error('Postgres:', e.message));
await migrate(pool);

const here = path.dirname(fileURLToPath(import.meta.url));
const staticDir = path.resolve(process.env.STATIC_DIR ?? path.join(here, '../app/build/web'));
const port = Number(process.env.PORT) || 3000;
createApp({ pool, staticDir }).listen(port, () => console.log(`Servidor en http://localhost:${port}`));
