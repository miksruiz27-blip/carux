// Dart puro: reglas y puntaje del reto. Misma fórmula que server/score.js.
import 'mru.dart';

/// Marcas que se tocan (m) y su tiempo real x/v (s).
const kRetoMarks = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30];
final kRealTimes = [for (final x in kRetoMarks) x / kV];
const kRounds = 3;
const kRoundEnd = 4.0; // s desde que la nariz cruza 0
const kMiss = 1.0; // marca sin tocar
const kMaxAttempts = 3;

/// Referencia del Equipo 4: diferencia promedio contra el ideal (s).
const kTeamGoal = 0.012;

/// Redondeo simétrico (mitades lejos de cero), igual que el server.
double roundTo(double x, [int d = 3]) {
  var k = 1.0;
  for (var i = 0; i < d; i++) {
    k *= 10;
  }
  return (x * k).round() / k;
}

int starsFor(double score) => score <= 0.05
    ? 5
    : score <= 0.1
        ? 4
        : score <= 0.2
            ? 3
            : score <= 0.35
                ? 2
                : 1;

class AttemptScore {
  const AttemptScore(this.score, this.stars, this.reactionAvg, this.velErrorPct);

  final double score;
  final int stars;

  /// Promedio con signo de (t_usuario − t_real); positivo = tarde. null sin toques.
  final double? reactionAvg;

  /// |pendiente − 0.10| / 0.10 × 100. null si no hay ajuste posible.
  final double? velErrorPct;
}

/// [rounds]: 3 listas de 6 tiempos (null = marca sin tocar).
AttemptScore scoreAttempt(List<List<double?>> rounds) {
  var absSum = 0.0, signedSum = 0.0, taps = 0;
  final ts = <double>[0], xs = <double>[0]; // la marca 0 cm siempre es t = 0
  for (var i = 0; i < kRetoMarks.length; i++) {
    final hit = [for (final r in rounds) ?r[i]];
    if (hit.isNotEmpty) {
      ts.add(hit.reduce((a, b) => a + b) / hit.length);
      xs.add(kRetoMarks[i]);
    }
    absSum += (rounds.length - hit.length) * kMiss;
    for (final t in hit) {
      absSum += (t - kRealTimes[i]).abs();
      signedSum += t - kRealTimes[i];
      taps++;
    }
  }
  final score = roundTo(absSum / (kRounds * kRetoMarks.length));
  final slope = ts.length < 2 ? double.nan : LinearFit(ts, xs).slope;
  return AttemptScore(
    score,
    starsFor(score),
    taps == 0 ? null : roundTo(signedSum / taps),
    slope.isFinite ? roundTo((slope - kV).abs() / kV * 100, 2) : null,
  );
}

/// Toques de una ronda: cada toque va a la siguiente marca pendiente.
class RoundTaps {
  final times = List<double?>.filled(kRetoMarks.length, null);
  var _next = 0;

  int get count => _next;

  /// [chrono]: tiempo desde que la nariz cruzó 0. Devuelve el índice de la
  /// marca asignada, o null si se ignora (antes del 0, de más o fuera de tiempo).
  int? tap(double chrono) {
    if (chrono < 0 || chrono > kRoundEnd || _next >= times.length) return null;
    times[_next] = roundTo(chrono); // milisegundos: lo mismo que recibe el server
    return _next++;
  }
}
