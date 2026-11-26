import 'package:flutter_test/flutter_test.dart';
import 'package:mru_app/physics/reto.dart';

// Mismos casos que server/test/score.test.js.
const perfect = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0];
List<List<double?>> three(List<double?> r) => [r, r, r];

void main() {
  test('tiempos reales: 0.50 s por cada 5 cm hasta 3.00 s', () {
    for (var i = 0; i < 6; i++) {
      expect(kRealTimes[i], closeTo(perfect[i], 1e-9));
    }
  });

  test('perfecto = 0.000, 5 estrellas, reacción 0, error de velocidad 0', () {
    final s = scoreAttempt(three(perfect));
    expect([s.score, s.stars, s.reactionAvg, s.velErrorPct], [0, 5, 0, 0]);
  });

  test('todos +0.2 s = 0.200 y reacción +0.200', () {
    final s = scoreAttempt(three([for (final t in perfect) t + 0.2]));
    expect([s.score, s.stars, s.reactionAvg], [0.2, 3, 0.2]);
  });

  test('todos −0.1 s: reacción negativa', () {
    final s = scoreAttempt(three([for (final t in perfect) t - 0.1]));
    expect([s.score, s.reactionAvg], [0.1, -0.1]);
  });

  test('una marca sin tocar suma 1/18', () {
    final s = scoreAttempt([
      [...perfect.take(5), null],
      perfect,
      perfect,
    ]);
    expect(s.score, roundTo(1 / 18));
    expect(s.reactionAvg, 0);
  });

  test('nada tocado = 1.000, 1 estrella, sin reacción ni velocidad', () {
    final s = scoreAttempt(three(List.filled(6, null)));
    expect([s.score, s.stars, s.reactionAvg, s.velErrorPct], [1, 1, null, null]);
  });

  test('tiempos ×1.25 → v = 0.08 → 20 %', () {
    expect(scoreAttempt(three([for (final t in perfect) t * 1.25])).velErrorPct, 20);
  });

  test('estrellas en los límites', () {
    expect([0.05, 0.051, 0.1, 0.2, 0.35, 0.351].map(starsFor), [5, 4, 4, 3, 2, 1]);
  });

  test('redondeo simétrico como el server', () {
    expect(roundTo(-0.0125), -0.013);
    expect(roundTo(0.0125), 0.013);
  });

  test('toques: antes del 0, de más y después de 4 s se ignoran', () {
    final r = RoundTaps();
    expect(r.tap(-0.1), isNull);
    for (var i = 0; i < 6; i++) {
      expect(r.tap(0.5 * (i + 1) + 0.0004), i);
    }
    expect(r.tap(3.5), isNull);
    expect(r.times, perfect);
    expect((RoundTaps()..tap(4.01)).count, 0);
  });
}
