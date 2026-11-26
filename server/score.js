// Fórmula del puntaje del reto. Debe dar exactamente lo mismo que el cliente Dart.

export const V = 0.10;
export const MARKS = [0.05, 0.10, 0.15, 0.20, 0.25, 0.30]; // m
export const REAL = MARKS.map((x) => x / V); // 0.5, 1.0, … 3.0 s
export const MISS = 1.0; // marca sin tocar
export const ROUND_END = 4.0;

// Redondeo simétrico (mitades lejos de cero) = Dart `(x * 10^d).round() / 10^d`.
export const round = (x, d = 3) => {
  const k = 10 ** d;
  return (Math.sign(x) * Math.round(Math.abs(x) * k)) / k;
};

/** null si es válido; si no, el motivo. */
export function validateRounds(rounds) {
  if (!Array.isArray(rounds) || rounds.length !== 3) return 'se esperan 3 rondas';
  for (const r of rounds) {
    if (!Array.isArray(r) || r.length !== 6) return 'cada ronda lleva 6 valores';
    let prev = -Infinity;
    for (const t of r) {
      if (t === null) continue;
      if (typeof t !== 'number' || !Number.isFinite(t) || t < 0 || t > ROUND_END) return 'valor fuera de rango';
      if (t < prev) return 'tiempos decrecientes';
      prev = t;
    }
  }
  return null;
}

export function stars(score) {
  if (score <= 0.05) return 5;
  if (score <= 0.1) return 4;
  if (score <= 0.2) return 3;
  if (score <= 0.35) return 2;
  return 1;
}

/** Pendiente de x contra t por mínimos cuadrados; null si no se puede. */
function slope(ts, xs) {
  const n = ts.length;
  if (n < 2) return null;
  const mt = ts.reduce((a, b) => a + b) / n;
  const mx = xs.reduce((a, b) => a + b) / n;
  let stt = 0, stx = 0;
  for (let i = 0; i < n; i++) {
    stt += (ts[i] - mt) ** 2;
    stx += (ts[i] - mt) * (xs[i] - mx);
  }
  return stt === 0 ? null : stx / stt;
}

/** Recibe rondas ya validadas. */
export function scoreAttempt(rounds) {
  let absSum = 0, signedSum = 0, taps = 0;
  const ts = [0], xs = [0]; // la marca 0 cm siempre es t = 0
  for (let i = 0; i < 6; i++) {
    const hit = rounds.map((r) => r[i]).filter((t) => t !== null);
    if (hit.length) {
      ts.push(hit.reduce((a, b) => a + b) / hit.length);
      xs.push(MARKS[i]);
    }
    absSum += (3 - hit.length) * MISS;
    for (const t of hit) {
      absSum += Math.abs(t - REAL[i]);
      signedSum += t - REAL[i];
      taps++;
    }
  }
  const score = round(absSum / 18);
  const m = slope(ts, xs);
  return {
    score,
    stars: stars(score),
    reactionAvg: taps ? round(signedSum / taps) : null,
    velErrorPct: m === null ? null : round((Math.abs(m - V) / V) * 100, 2),
  };
}
