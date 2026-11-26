import { test } from 'node:test';
import assert from 'node:assert/strict';
import { scoreAttempt, validateRounds, stars, round } from '../score.js';
import { normalizeName } from '../names.js';

// Mismos casos que app/test (cliente Dart).
const PERFECT = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0];
const rounds = (r) => [r, r, r];

test('perfecto = 0.000, 5 estrellas, reacción 0, error de velocidad 0', () => {
  assert.deepEqual(scoreAttempt(rounds(PERFECT)), { score: 0, stars: 5, reactionAvg: 0, velErrorPct: 0 });
});

test('todos +0.2 s = 0.200 y reacción +0.200', () => {
  const s = scoreAttempt(rounds(PERFECT.map((t) => t + 0.2)));
  assert.equal(s.score, 0.2);
  assert.equal(s.stars, 3);
  assert.equal(s.reactionAvg, 0.2);
});

test('todos −0.1 s: reacción negativa (temprano)', () => {
  const s = scoreAttempt(rounds(PERFECT.map((t) => t - 0.1)));
  assert.equal(s.score, 0.1);
  assert.equal(s.reactionAvg, -0.1);
});

test('una marca sin tocar suma 1/18', () => {
  const r = [[...PERFECT.slice(0, 5), null], PERFECT, PERFECT];
  const s = scoreAttempt(r);
  assert.equal(s.score, round(1 / 18)); // 0.056
  assert.equal(s.reactionAvg, 0); // solo cuentan los toques hechos
});

test('nada tocado = 1.000, 1 estrella, sin reacción ni velocidad', () => {
  assert.deepEqual(scoreAttempt(rounds(Array(6).fill(null))), { score: 1, stars: 1, reactionAvg: null, velErrorPct: null });
});

test('error de velocidad: tiempos ×1.25 → v = 0.08 → 20 %', () => {
  assert.equal(scoreAttempt(rounds(PERFECT.map((t) => t * 1.25))).velErrorPct, 20);
});

test('estrellas en los límites', () => {
  assert.deepEqual([0.05, 0.051, 0.1, 0.2, 0.35, 0.351].map(stars), [5, 4, 4, 3, 2, 1]);
});

test('redondeo simétrico como Dart', () => {
  assert.equal(round(-0.0125), -0.013);
  assert.equal(round(0.0125), 0.013);
});

test('validación de rondas', () => {
  assert.equal(validateRounds(rounds(PERFECT)), null);
  assert.equal(validateRounds(rounds([null, 1, null, 2, 4.0, null])), null);
  assert.ok(validateRounds([PERFECT, PERFECT])); // 2 rondas
  assert.ok(validateRounds(rounds(PERFECT.slice(0, 5)))); // 5 valores
  assert.ok(validateRounds(rounds([0.5, 1, 1.5, 2, 2.5, 4.01]))); // > 4.0
  assert.ok(validateRounds(rounds([-0.1, 1, 1.5, 2, 2.5, 3]))); // < 0
  assert.ok(validateRounds(rounds([0.5, 1, 0.9, 2, 2.5, 3]))); // decrece
  assert.ok(validateRounds(rounds([0.5, '1', 1.5, 2, 2.5, 3]))); // texto
  assert.ok(validateRounds(null));
});

test('nombres: recorte, espacios, longitud, clave sin acentos', () => {
  assert.deepEqual(normalizeName('  José   Ángel '), { displayName: 'José Ángel', nameKey: 'jose angel' });
  assert.equal(normalizeName('a').error, 'nombre_invalido');
  assert.equal(normalizeName('x'.repeat(17)).error, 'nombre_invalido');
  assert.ok(!normalizeName('x'.repeat(16)).error);
  assert.equal(normalizeName(42).error, 'nombre_invalido');
  assert.equal(normalizeName('\u{FFFD}na').error, 'nombre_invalido');
  assert.ok(!normalizeName('Zoë 🚗').error);
});

test('groserías: directas, con acentos, mayúsculas y números', () => {
  for (const n of ['puto', 'PENDEJO', 'Cabrón', 'p3nd3j0', 'pu7a', 'chinga tu', 'pen dejo'])
    assert.equal(normalizeName(n).error, 'nombre_no_permitido', n);
  for (const n of ['Computadora', 'Ana', 'Equipo 4', 'Diputado']) assert.ok(!normalizeName(n).error, n);
});
