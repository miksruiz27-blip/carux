// Dart puro: sin imports de Flutter.
import 'dart:math' as math;

/// Velocidad constante de la práctica (m/s).
const double kV = 0.10;

/// Marcas de la regla (m).
const kMarks = [0.0, 0.05, 0.10, 0.15, 0.20, 0.25, 0.30];

/// Tiempos promedio medidos por el Equipo 4 (s), uno por marca de [kMarks].
const kTeamTimes = [0.00, 0.50, 1.00, 1.50, 2.04, 2.53, 3.00];

/// Fuente de verdad del tiempo de simulación. Se detiene al pausar.
class SimClock {
  final _sw = Stopwatch();

  double get seconds => _sw.elapsedMicroseconds / 1e6;
  bool get running => _sw.isRunning;

  void start() => _sw.start();
  void pause() => _sw.stop();
  void reset() => _sw
    ..stop()
    ..reset();
}

/// Movimiento de la nariz del carrito. t = tiempo desde que se libera.
///
/// - Normal: se libera [preRun] antes del 0 y va a v constante: x = x₀ + v·t.
/// - [fromZero]: se suelta en reposo en el 0, acelera uniformemente durante
///   [accelDist] hasta alcanzar v y luego sigue a v constante.
class CartMotion {
  const CartMotion({this.v = kV, this.fromZero = false, this.xEnd = 0.30});

  final double v, xEnd;
  final bool fromZero;

  static const preRun = 0.03;
  static const accelDist = 0.05;

  double get x0 => fromZero ? 0 : -preRun;

  /// Duración de la fase de aceleración (modo [fromZero]).
  double get _ta => 2 * accelDist / v;

  double positionAt(double t) {
    final double x;
    if (!fromZero) {
      x = x0 + v * t;
    } else if (t < _ta) {
      x = 0.5 * (v / _ta) * t * t;
    } else {
      x = accelDist + v * (t - _ta);
    }
    return math.min(x, xEnd);
  }

  /// Tiempo desde la liberación en que la nariz llega a [x] (x ≥ x₀).
  double timeAt(double x) {
    if (!fromZero) return (x - x0) / v;
    if (x <= accelDist) return math.sqrt(2 * x * _ta / v);
    return _ta + (x - accelDist) / v;
  }

  /// Tiempo de cronómetro (desde que la nariz cruzó 0) al llegar a [x].
  double crossingTime(double x) => timeAt(x) - timeAt(0);

  /// Cronómetro: 0 en la zona de arranque, congelado al llegar a [xEnd].
  double chronoAt(double t) =>
      (t - timeAt(0)).clamp(0.0, crossingTime(xEnd)).toDouble();

  /// Duración medida por el cronómetro (de 0 a [xEnd]).
  double get duration => crossingTime(xEnd);

  /// Tiempo desde la liberación en que la nariz llega al final.
  double get endTime => timeAt(xEnd);

  /// ¿La nariz ya cruzó [x] en el instante [t]? (t = 0 es "no iniciado").
  bool crossed(double x, double t) => t > 0 && t >= timeAt(x);
}

/// Ajuste lineal por mínimos cuadrados de y contra x.
class LinearFit {
  LinearFit._(this.slope, this.intercept, this.r2);

  factory LinearFit(List<double> xs, List<double> ys) {
    assert(xs.length == ys.length && xs.length >= 2);
    final n = xs.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var sxx = 0.0, sxy = 0.0, syy = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = xs[i] - mx, dy = ys[i] - my;
      sxx += dx * dx;
      sxy += dx * dy;
      syy += dy * dy;
    }
    final slope = sxy / sxx;
    final r2 = syy == 0 ? 1.0 : (sxy * sxy) / (sxx * syy);
    return LinearFit._(slope, my - slope * mx, r2);
  }

  final double slope, intercept, r2;

  double at(double x) => intercept + slope * x;
}

/// Ajuste x-t de una simulación completa (las 7 marcas).
LinearFit simFit(CartMotion m) =>
    LinearFit([for (final x in kMarks) m.crossingTime(x)], kMarks);

/// Ajuste x-t de los datos reales del Equipo 4.
final teamFit = LinearFit(kTeamTimes, kMarks);
