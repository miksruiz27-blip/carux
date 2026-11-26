// Requiere Postgres: TEST_DATABASE_URL=postgres://… npm test  (se BORRAN sus tablas).
import { test, before, beforeEach, after } from 'node:test';
import assert from 'node:assert/strict';
import pg from 'pg';
import request from 'supertest';
import { createApp, migrate } from '../app.js';

const url = process.env.TEST_DATABASE_URL;
const opts = { skip: !url && 'falta TEST_DATABASE_URL' };
const PIN = '4321';
const PERFECT = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0];
const R = (d = 0) => Array(3).fill(PERFECT.map((t) => t + d));

let pool, app;
before(async () => {
  if (!url) return;
  pool = new pg.Pool({ connectionString: url });
  await pool.query('DROP TABLE IF EXISTS events, attempts, sessions');
  await migrate(pool);
  await migrate(pool); // idempotente
});
beforeEach(async () => {
  if (!url) return;
  await pool.query('TRUNCATE events, attempts, sessions RESTART IDENTITY');
  await migrate(pool);
  app = createApp({ pool, adminPin: PIN, limits: false });
});
after(() => pool?.end());

const post = (path, body) => request(app).post(path).send(body);

test('health', opts, async () => {
  assert.deepEqual((await request(app).get('/api/health')).body, { ok: true });
});

test('join: valida y registra un solo evento por 60 s', opts, async () => {
  const r = await post('/api/join', { name: '  Ana  María ' });
  assert.deepEqual(r.body, { sessionId: 1, displayName: 'Ana María', attemptsUsed: 0, attemptsLeft: 3 });
  await post('/api/join', { name: 'ana maria' });
  assert.equal((await pool.query("SELECT count(*)::int n FROM events WHERE type='joined'")).rows[0].n, 1);
  assert.equal((await post('/api/join', { name: 'x' })).status, 400);
  assert.equal((await post('/api/join', { name: 'p3nd3j0' })).body.error, 'nombre_no_permitido');
});

test('intento: el servidor recalcula el puntaje', opts, async () => {
  const r = await post('/api/attempts', { name: 'Ana', rounds: R(0.2), score: 0 });
  assert.equal(r.status, 200);
  assert.deepEqual(r.body, { score: 0.2, stars: 3, rank: 1, bestScore: 0.2, attemptsLeft: 2 });
});

test('rondas inválidas = 400', opts, async () => {
  for (const rounds of [R().slice(0, 2), [PERFECT, PERFECT, [0.5, 1, 0.9, 2, 2.5, 3]], [PERFECT, PERFECT, [0.5, 1, 1.5, 2, 2.5, 4.5]], 'x']) {
    const r = await post('/api/attempts', { name: 'Ana', rounds });
    assert.equal(r.status, 400);
    assert.equal(r.body.error, 'rondas_invalidas');
  }
  const bad = await request(app).post('/api/attempts').set('Content-Type', 'application/json').send('{no');
  assert.deepEqual([bad.status, bad.body.error], [400, 'json_invalido']);
});

test('límite de 3 intentos por nombre (sin mayúsculas ni acentos); cuenta el mejor', opts, async () => {
  for (const [name, d] of [['José', 0.3], ['jose', 0.1], ['JOSÉ', 0.2]]) assert.equal((await post('/api/attempts', { name, rounds: R(d) })).status, 200);
  const r = await post('/api/attempts', { name: 'Jose', rounds: R() });
  assert.deepEqual([r.status, r.body], [409, { error: 'sin_intentos' }]);
  const lb = (await request(app).get('/api/leaderboard?name=josé')).body;
  assert.equal(lb.top.length, 1);
  assert.equal(lb.top[0].score, 0.1);
  assert.deepEqual(lb.me, { rank: 1, bestScore: 0.1, attemptsLeft: 0 });
});

test('empate: gana el intento más antiguo', opts, async () => {
  await post('/api/attempts', { name: 'Primero', rounds: R(0.1) });
  const b = await post('/api/attempts', { name: 'Segundo', rounds: R(0.1) });
  assert.equal(b.body.rank, 2);
  await post('/api/attempts', { name: 'Tercero', rounds: R(0.05) });
  const lb = (await request(app).get('/api/leaderboard?name=segundo')).body;
  assert.deepEqual(lb.top.map((t) => t.displayName), ['Tercero', 'Primero', 'Segundo']);
  assert.equal(lb.me.rank, 3);
  assert.equal(lb.players, 3);
  assert.deepEqual(lb.recent.map((e) => [e.type, e.displayName, e.rank]), [
    ['finished', 'Tercero', 1],
    ['finished', 'Segundo', 2],
    ['finished', 'Primero', 1],
  ]);
});

test('leaderboard: top 10 y me null sin nombre', opts, async () => {
  for (let i = 0; i < 12; i++) await post('/api/attempts', { name: `Jugador ${i}`, rounds: R(i / 100) });
  const lb = (await request(app).get('/api/leaderboard')).body;
  assert.equal(lb.top.length, 10);
  assert.equal(lb.me, null);
  assert.equal(lb.recent.length, 8);
  assert.equal(lb.players, 12);
  const me = (await request(app).get('/api/leaderboard?name=Nuevo')).body.me;
  assert.deepEqual(me, { rank: null, bestScore: null, attemptsLeft: 3 });
});

test('reset: PIN incorrecto = 401, correcto abre sesión nueva', opts, async () => {
  await post('/api/attempts', { name: 'Ana', rounds: R() });
  assert.equal((await request(app).post('/api/admin/reset')).status, 401);
  assert.equal((await request(app).post('/api/admin/reset').set('X-Admin-Pin', '0000')).status, 401);
  const ok = await request(app).post('/api/admin/reset').set('X-Admin-Pin', PIN);
  assert.deepEqual([ok.status, ok.body], [200, { sessionId: 2 }]);
  const lb = (await request(app).get('/api/leaderboard?name=Ana')).body;
  assert.deepEqual([lb.sessionId, lb.top, lb.me.attemptsLeft], [2, [], 3]);
  assert.equal((await pool.query('SELECT count(*)::int n FROM sessions WHERE active')).rows[0].n, 1);
});

test('reset: 5 fallos → 429', opts, async () => {
  for (let i = 0; i < 5; i++) assert.equal((await request(app).post('/api/admin/reset').set('X-Admin-Pin', 'no')).status, 401);
  assert.equal((await request(app).post('/api/admin/reset').set('X-Admin-Pin', PIN)).status, 429);
});

test('reset deshabilitado sin ADMIN_PIN', opts, async () => {
  const r = await request(createApp({ pool, adminPin: '', limits: false })).post('/api/admin/reset').set('X-Admin-Pin', '');
  assert.equal(r.status, 503);
});

test('rate limit: 31.º POST en un minuto = 429', opts, async () => {
  const limited = createApp({ pool, adminPin: PIN });
  for (let i = 0; i < 30; i++) await request(limited).post('/api/join').send({ name: 'Ana' }).expect(200);
  await request(limited).post('/api/join').send({ name: 'Ana' }).expect(429);
  await request(limited).get('/api/health').expect(200); // GET tiene su propio cupo
});
