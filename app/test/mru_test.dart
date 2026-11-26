import 'package:flutter_test/flutter_test.dart';
import 'package:mru_app/physics/mru.dart';

void main() {
  const m = CartMotion();

  test('0.50 s por cada 5 cm con v = 0.10 m/s', () {
    for (var cm = 5; cm <= 30; cm += 5) {
      expect(m.crossingTime(cm / 100), closeTo(cm / 10, 1e-9), reason: '$cm cm');
      expect((cm / 100) / m.crossingTime(cm / 100), closeTo(0.100, 1e-9));
    }
  });

  test('cronómetro marca 3.00 s al llegar a 30 cm', () {
    expect(m.chronoAt(m.timeAt(0.30)), closeTo(3.00, 1e-9));
    expect(m.duration, closeTo(3.00, 1e-9));
  });

  test('antes del 0 el cronómetro está en 0 y la nariz en la zona de arranque', () {
    expect(m.chronoAt(0), 0);
    expect(m.positionAt(0), m.x0);
    expect(m.x0, lessThan(0));
    expect(m.crossed(0, 0), isFalse);
  });

  test('la posición se detiene en 30 cm y el cronómetro en 3.00 s', () {
    expect(m.positionAt(m.endTime + 5), 0.30);
    expect(m.chronoAt(m.endTime + 5), closeTo(3.00, 1e-9));
  });

  test('ajuste con 0.10 m/s: pendiente 0.100, R² 1', () {
    final f = simFit(m);
    expect(f.slope, closeTo(0.100, 1e-9));
    expect(f.r2, closeTo(1, 1e-9));
  });

  test('ajuste con 0.20 m/s: pendiente 0.200', () {
    expect(simFit(const CartMotion(v: 0.20)).slope, closeTo(0.200, 1e-9));
    expect(const CartMotion(v: 0.20).duration, closeTo(1.50, 1e-9));
  });

  test('soltar en el 0: llega a 30 cm en 3.50 s y el R² baja', () {
    const a = CartMotion(fromZero: true);
    expect(a.duration, closeTo(3.50, 1e-9));
    expect(a.crossingTime(0.05), closeTo(1.00, 1e-9));
    expect(a.positionAt(a.timeAt(0.05)), closeTo(0.05, 1e-9)); // continuidad
    expect(a.positionAt(0), 0);
    expect(simFit(a).r2, lessThan(0.999));
  });

  test('datos del Equipo 4: pendiente 0.099 m/s, R² 0.9998', () {
    expect(teamFit.slope.toStringAsFixed(3), '0.099');
    expect(teamFit.r2.toStringAsFixed(4), '0.9998');
  });

  test('SimClock: pausar congela el tiempo, reiniciar lo regresa a 0', () async {
    final c = SimClock()..start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    c.pause();
    final t = c.seconds;
    expect(t, greaterThan(0));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.seconds, t);
    c.reset();
    expect(c.seconds, 0);
    expect(c.running, isFalse);
  });
}
