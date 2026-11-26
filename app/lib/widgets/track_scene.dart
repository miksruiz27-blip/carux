import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../physics/mru.dart';
import '../theme.dart';

/// Flash de una marca al ser cruzada (s).
const kFlashSeconds = 0.4;

/// Escena: mesa, regla, carrito y cronómetro. Solo muestra el estado que
/// recibe; el reloj y el Ticker viven en la pantalla que la usa.
class TrackScene extends StatelessWidget {
  const TrackScene({super.key, required this.motion, required this.t});

  final CartMotion motion;

  /// Tiempo de simulación desde la liberación (s).
  final double t;

  /// Marca (cm) → intensidad 1..0 del destello, según el tiempo de cruce.
  Map<int, double> _flashes() => {
        for (final x in kMarks)
          if (motion.crossed(x, t) && t - motion.timeAt(x) < kFlashSeconds)
            (x * 100).round(): 1 - (t - motion.timeAt(x)) / kFlashSeconds,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: TrackPainter(
                  noseX: motion.positionAt(t),
                  flashes: _flashes(),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kBg.withValues(alpha: 0.85),
                border: Border.all(color: kBorder),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${motion.chronoAt(t).toStringAsFixed(2).padLeft(5, '0')} s',
                style: mono(size: 20, color: kAccent, weight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista cenital. Solo dibuja: recibe la posición de la nariz (m) y los
/// destellos activos (cm → intensidad 0..1). No calcula física.
class TrackPainter extends CustomPainter {
  TrackPainter({required this.noseX, required this.flashes});

  final double noseX;
  final Map<int, double> flashes;

  // Rango visible en cm: deja ver el carrito completo en la zona de arranque.
  static const _minCm = -10.0, _maxCm = 32.0, _margin = 12.0;
  static const _startZoneCm = 7.0;
  static const _cartCm = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final ppc = (size.width - 2 * _margin) / (_maxCm - _minCm);
    double px(double cm) => _margin + (cm - _minCm) * ppc;

    const rulerTop = 48.0, rulerH = 40.0;
    final trackTop = rulerTop + rulerH + 8;
    final trackY = (trackTop + size.height) / 2;

    _paintWood(canvas, size);

    // Zona de arranque.
    final zone = Rect.fromLTRB(px(-_startZoneCm), trackTop, px(0), size.height - 6);
    canvas.drawRect(zone, Paint()..color = Colors.black.withValues(alpha: 0.28));
    canvas.save();
    canvas.clipRect(zone);
    final hatch = Paint()
      ..color = kAccent.withValues(alpha: 0.12)
      ..strokeWidth = 2;
    for (var x = zone.left - zone.height; x < zone.right; x += 10) {
      canvas.drawLine(Offset(x, zone.bottom), Offset(x + zone.height, zone.top), hatch);
    }
    canvas.restore();
    _text(canvas, 'ARRANQUE', Offset(zone.center.dx, zone.bottom - 8),
        size: math.min(10, ppc * 1.2), color: kText.withValues(alpha: 0.7));

    // Regla.
    final ruler = Rect.fromLTRB(px(-0.8), rulerTop, px(30.8), rulerTop + rulerH);
    canvas.drawRRect(
        RRect.fromRectAndRadius(ruler.shift(const Offset(0, 3)), const Radius.circular(3)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawRRect(RRect.fromRectAndRadius(ruler, const Radius.circular(3)),
        Paint()..color = const Color(0xFFEDE3C4));

    final tick = Paint()
      ..color = const Color(0xFF2B2B2B)
      ..strokeWidth = 1;
    for (var cm = 0; cm <= 30; cm++) {
      final big = cm % 5 == 0;
      final x = px(cm.toDouble());
      canvas.drawLine(Offset(x, rulerTop),
          Offset(x, rulerTop + rulerH * (big ? 0.5 : 0.25)), tick..strokeWidth = big ? 1.6 : 1);
    }

    // Marcas de 5 cm: número, línea guía sobre la pista y destello.
    for (var cm = 0; cm <= 30; cm += 5) {
      final x = px(cm.toDouble());
      final f = flashes[cm] ?? 0;
      _text(canvas, '$cm', Offset(x, rulerTop + rulerH * 0.76),
          size: math.min(12, ppc * 1.6),
          color: Color.lerp(const Color(0xFF2B2B2B), const Color(0xFF3E6B00), f)!,
          bold: f > 0);
      canvas.drawLine(Offset(x, trackTop), Offset(x, size.height - 6),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.10)
            ..strokeWidth = 1);
      if (f > 0) {
        final glow = Paint()
          ..color = kAccent.withValues(alpha: f)
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawLine(Offset(x, rulerTop), Offset(x, size.height - 6), glow);
        canvas.drawLine(Offset(x, rulerTop), Offset(x, size.height - 6),
            Paint()
              ..color = kAccent.withValues(alpha: f)
              ..strokeWidth = 2);
      }
    }

    _paintCart(canvas, px(noseX * 100), trackY, _cartCm * ppc,
        math.min(_cartCm * ppc * 0.55, (size.height - trackTop) * 0.5));
  }

  void _paintWood(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7A5230), Color(0xFF6B4423), Color(0xFF7D5533), Color(0xFF5E3A1E)],
          stops: [0, 0.35, 0.7, 1],
        ).createShader(rect),
    );
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)));
    final rnd = math.Random(7); // semilla fija: vetas iguales en cada frame
    for (var i = 0; i < 26; i++) {
      final y0 = rnd.nextDouble() * size.height;
      final amp = 1 + rnd.nextDouble() * 4;
      final freq = 0.004 + rnd.nextDouble() * 0.01;
      final phase = rnd.nextDouble() * math.pi * 2;
      final path = Path()..moveTo(0, y0);
      for (double x = 0; x <= size.width; x += 8) {
        path.lineTo(x, y0 + math.sin(x * freq + phase) * amp);
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.6 + rnd.nextDouble() * 1.6
            ..color = (i.isEven ? Colors.black : const Color(0xFFB98552))
                .withValues(alpha: 0.06 + rnd.nextDouble() * 0.08));
    }
    canvas.restore();
  }

  void _paintCart(Canvas canvas, double nose, double cy, double len, double w) {
    final left = nose - len;
    // Llantas.
    final wheel = Paint()..color = const Color(0xFF1A1A1A);
    final ww = len * 0.17, wh = w * 0.24;
    for (final fx in [0.22, 0.78]) {
      for (final sy in [-1, 1]) {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(center: Offset(left + len * fx, cy + sy * w / 2), width: ww, height: wh),
                Radius.circular(wh * 0.3)),
            wheel);
      }
    }
    // Sombra y carrocería.
    final body = RRect.fromRectAndRadius(
        Rect.fromLTRB(left, cy - w / 2, nose, cy + w / 2), Radius.circular(w * 0.3));
    canvas.drawRRect(
        body.shift(const Offset(2, 4)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawRRect(
        body,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFF4FA3FF), Color(0xFF1F6FD1)],
          ).createShader(body.outerRect));
    // Cabina.
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTRB(left + len * 0.3, cy - w * 0.3, nose - len * 0.3, cy + w * 0.3),
            Radius.circular(w * 0.15)),
        Paint()..color = Colors.white.withValues(alpha: 0.18));
    // Nariz: triángulo al frente + línea exacta en la posición.
    canvas.drawPath(
        Path()
          ..moveTo(nose - len * 0.2, cy - w * 0.28)
          ..lineTo(nose - 1.5, cy)
          ..lineTo(nose - len * 0.2, cy + w * 0.28)
          ..close(),
        Paint()..color = kAccent);
    canvas.drawLine(Offset(nose, cy - w / 2 - 4), Offset(nose, cy + w / 2 + 4),
        Paint()
          ..color = kAccent
          ..strokeWidth = 2);
  }

  void _text(Canvas canvas, String s, Offset center,
      {double size = 12, Color color = kText, bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
          text: s,
          style: mono(size: size, color: color, weight: bold ? FontWeight.w800 : FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(TrackPainter old) =>
      old.noseX != noseX || old.flashes.toString() != flashes.toString();
}
