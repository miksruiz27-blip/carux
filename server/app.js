import { createHash, timingSafeEqual } from 'node:crypto';
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';
import compression from 'compression';
import express from 'express';
import rateLimit from 'express-rate-limit';
import { normalizeName } from './names.js';
import { validateRounds, scoreAttempt } from './score.js';

const MAX_ATTEMPTS = 3;

export async function migrate(pool) {
  // Con otra codificación los nombres con emoji o caracteres raros darían 500.
  const enc = (await pool.query('SHOW server_encoding')).rows[0].server_encoding;
  if (enc !== 'UTF8') throw new Error(`La base de datos debe ser UTF8 (es ${enc})`);
  await pool.query(readFileSync(new URL('./schema.sql', import.meta.url), 'utf8'));
}

const activeSession = async (db, lock = '') =>
  (await db.query(`SELECT id FROM sessions WHERE active ${lock}`)).rows[0].id;

// Mejor intento por nombre (menor score; si empata, el más antiguo) y su posición.
// ponytail: calcula la tabla completa en cada consulta; basta para un salón, paginar si crece.
async function ranking(db, sessionId) {
  const { rows } = await db.query(
    `SELECT name_key, display_name, score::float8 AS score, stars, created_at,
            row_number() OVER (ORDER BY score, created_at, id)::int AS rank
       FROM (SELECT DISTINCT ON (name_key) *
               FROM attempts WHERE session_id = $1
              ORDER BY name_key, score, created_at, id) best
      ORDER BY rank`,
    [sessionId],
  );
  return rows;
}

const attemptsUsed = async (db, sessionId, nameKey) =>
  (await db.query('SELECT count(*)::int AS n FROM attempts WHERE session_id = $1 AND name_key = $2', [sessionId, nameKey]))
    .rows[0].n;

const sha = (s) => createHash('sha256').update(String(s)).digest();

export function createApp({ pool, adminPin = process.env.ADMIN_PIN, staticDir, limits = true, corsOrigin = process.env.CORS_ORIGIN }) {
  const app = express();
  app.set('trust proxy', 1); // Railway pone un proxy delante
  app.use(compression()); // main.dart.js ≈ 3.1 MB → ~0.9 MB con gzip; importa con datos móviles
  const api = express.Router();
  // Solo desarrollo (flutter run en otro puerto). En producción es el mismo origen.
  if (corsOrigin) {
    api.use((req, res, next) => {
      res.set({ 'Access-Control-Allow-Origin': corsOrigin, 'Access-Control-Allow-Headers': 'Content-Type, X-Admin-Pin' });
      if (req.method === 'OPTIONS') return res.sendStatus(204);
      next();
    });
  }
  api.use(express.json({ limit: '10kb' }));

  if (limits) {
    const opts = { windowMs: 60_000, standardHeaders: 'draft-7', legacyHeaders: false, message: { error: 'demasiadas_solicitudes' } };
    api.use(rateLimit({ ...opts, limit: 30, skip: (req) => req.method !== 'POST' }));
    api.use(rateLimit({ ...opts, limit: 60, skip: (req) => req.method !== 'GET' }));
  }

  api.get('/health', (req, res) => res.json({ ok: true }));

  api.post('/join', async (req, res) => {
    const n = normalizeName(req.body?.name);
    if (n.error) return res.status(400).json({ error: n.error });
    const sessionId = await activeSession(pool);
    await pool.query(
      `INSERT INTO events (session_id, type, name_key, display_name)
       SELECT $1, 'joined', $2, $3
        WHERE NOT EXISTS (SELECT 1 FROM events WHERE session_id = $1 AND type = 'joined'
                            AND name_key = $2 AND created_at > now() - interval '60 seconds')`,
      [sessionId, n.nameKey, n.displayName],
    );
    const used = await attemptsUsed(pool, sessionId, n.nameKey);
    res.json({ sessionId, displayName: n.displayName, attemptsUsed: used, attemptsLeft: Math.max(0, MAX_ATTEMPTS - used) });
  });

  api.post('/attempts', async (req, res) => {
    const n = normalizeName(req.body?.name);
    if (n.error) return res.status(400).json({ error: n.error });
    const why = validateRounds(req.body?.rounds);
    if (why) return res.status(400).json({ error: 'rondas_invalidas', detalle: why });
    const s = scoreAttempt(req.body.rounds);

    const db = await pool.connect();
    try {
      await db.query('BEGIN');
      // ponytail: bloquea la sesión activa = serializa todos los intentos (y el reset); suficiente para un salón.
      const sessionId = await activeSession(db, 'FOR UPDATE');
      const used = await attemptsUsed(db, sessionId, n.nameKey);
      if (used >= MAX_ATTEMPTS) {
        await db.query('ROLLBACK');
        return res.status(409).json({ error: 'sin_intentos' });
      }
      await db.query(
        `INSERT INTO attempts (session_id, name_key, display_name, rounds, score, vel_error_pct, reaction_avg, stars, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, clock_timestamp())`,
        [sessionId, n.nameKey, n.displayName, JSON.stringify(req.body.rounds), s.score, s.velErrorPct, s.reactionAvg, s.stars],
      );
      const me = (await ranking(db, sessionId)).find((r) => r.name_key === n.nameKey);
      await db.query(
        `INSERT INTO events (session_id, type, name_key, display_name, rank, created_at)
         VALUES ($1, 'finished', $2, $3, $4, clock_timestamp())`,
        [sessionId, n.nameKey, n.displayName, me.rank],
      );
      await db.query('COMMIT');
      res.json({ score: s.score, stars: s.stars, rank: me.rank, bestScore: me.score, attemptsLeft: MAX_ATTEMPTS - used - 1 });
    } catch (e) {
      await db.query('ROLLBACK').catch(() => {});
      throw e;
    } finally {
      db.release();
    }
  });

  api.get('/leaderboard', async (req, res) => {
    const sessionId = await activeSession(pool);
    const rows = await ranking(pool, sessionId);
    const top = rows.slice(0, 10).map((r) => ({ rank: r.rank, displayName: r.display_name, score: r.score, stars: r.stars }));

    let me = null;
    const n = typeof req.query.name === 'string' ? normalizeName(req.query.name) : { error: true };
    if (!n.error) {
      const mine = rows.find((r) => r.name_key === n.nameKey);
      const used = await attemptsUsed(pool, sessionId, n.nameKey);
      me = { rank: mine?.rank ?? null, bestScore: mine?.score ?? null, attemptsLeft: Math.max(0, MAX_ATTEMPTS - used) };
    }

    const recent = (
      await pool.query(
        `SELECT type, display_name AS "displayName", rank, created_at AS "createdAt"
           FROM events WHERE session_id = $1 ORDER BY created_at DESC, id DESC LIMIT 8`,
        [sessionId],
      )
    ).rows;
    const players = (await pool.query('SELECT count(DISTINCT name_key)::int AS n FROM events WHERE session_id = $1', [sessionId]))
      .rows[0].n;

    res.json({ sessionId, top, me, recent, players, serverTime: new Date().toISOString() });
  });

  const adminLimit = rateLimit({
    windowMs: 10 * 60_000,
    limit: 5,
    skipSuccessfulRequests: true,
    standardHeaders: 'draft-7',
    legacyHeaders: false,
    message: { error: 'demasiados_intentos' },
  });
  api.post('/admin/reset', adminLimit, async (req, res) => {
    if (!adminPin) return res.status(503).json({ error: 'reset_deshabilitado' });
    const pin = req.get('X-Admin-Pin');
    // Comparar hashes: timingSafeEqual exige la misma longitud y así no se filtra la del PIN.
    if (!pin || !timingSafeEqual(sha(pin), sha(adminPin))) return res.status(401).json({ error: 'pin_incorrecto' });

    const db = await pool.connect();
    try {
      await db.query('BEGIN');
      await db.query('UPDATE sessions SET active = false WHERE active');
      const { id } = (await db.query('INSERT INTO sessions (active) VALUES (true) RETURNING id')).rows[0];
      await db.query('COMMIT');
      res.json({ sessionId: id });
    } catch (e) {
      await db.query('ROLLBACK').catch(() => {});
      throw e;
    } finally {
      db.release();
    }
  });

  api.use((req, res) => res.status(404).json({ error: 'no_encontrado' }));
  api.use((err, req, res, next) => {
    if (err.type === 'entity.parse.failed') return res.status(400).json({ error: 'json_invalido' });
    if (err.type === 'entity.too.large') return res.status(413).json({ error: 'demasiado_grande' });
    console.error(err);
    res.status(500).json({ error: 'error_interno' });
  });
  app.use('/api', api);

  if (staticDir) {
    const index = path.join(staticDir, 'index.html');
    app.use(express.static(staticDir));
    app.get(/.*/, (req, res) =>
      existsSync(index) ? res.sendFile(index) : res.status(404).send('Falta la build de Flutter: cd app && flutter build web'),
    );
  }
  return app;
}
