import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../physics/mru.dart';
import '../theme.dart';

/// Gráfica posición-tiempo. Solo dibuja lo que recibe.
class XtPainter extends CustomPainter {
  XtPainter({
    required this.tMax,
    required this.points,
    this.fit,
    this.teamPoints,
    this.teamFit,
  });

  final double tMax;

  /// Puntos (t, x) de la simulación, en s y m.
  final List<(double, double)> points;
  final LinearFit? fit;
  final List<(double, double)>? teamPoints;
  final LinearFit? teamFit;

  static const _xMax = 0.30;
  static const _padL = 52.0, _padR = 12.0, _padT = 12.0, _padB = 40.0;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(_padL, _padT, size.width - _padR, size.height - _padB);
    Offset p(double t, double x) => Offset(
        plot.left + t / tMax * plot.width, plot.bottom - x / _xMax * plot.height);

    // Cuadrícula y etiquetas.
    final grid = Paint()
      ..color = kBorder
      ..strokeWidth = 1;
    final tStep = tMax <= 4 ? 0.5 : 1.0;
    for (var t = 0.0; t <= tMax + 1e-9; t += tStep) {
      canvas.drawLine(p(t, 0), p(t, _xMax), grid);
      _text(canvas, t.toStringAsFixed(1), p(t, 0) + const Offset(0, 12));
    }
    for (var i = 0; i <= 6; i++) {
      final x = i * 0.05;
      canvas.drawLine(p(0, x), p(tMax, x), grid);
      _text(canvas, x.toStringAsFixed(2), p(0, x) - const Offset(24, 0));
    }
    // Ejes.
    final axis = Paint()
      ..color = kMuted
      ..strokeWidth = 1.5;
    canvas.drawLine(plot.bottomLeft, plot.bottomRight, axis);
    canvas.drawLine(plot.bottomLeft, plot.topLeft, axis);
    _text(canvas, 't (s)', Offset(plot.center.dx, size.height - 8), color: kText);
    canvas.save();
    canvas.translate(10, plot.center.dy);
    canvas.rotate(-math.pi / 2);
    _text(canvas, 'x (m)', Offset.zero, color: kText);
    canvas.restore();

    canvas.save();
    canvas.clipRect(plot.inflate(6));
    _series(canvas, p, teamPoints, teamFit, kTeam);
    _series(canvas, p, points, fit, kAccent);
    canvas.restore();
  }

  void _series(Canvas canvas, Offset Function(double, double) p,
      List<(double, double)>? pts, LinearFit? f, Color color) {
    if (f != null) {
      canvas.drawLine(
          p(0, f.at(0)),
          p(tMax, f.at(tMax)),
          Paint()
            ..color = color.withValues(alpha: 0.7)
            ..strokeWidth = 2);
    }
    for (final (t, x) in pts ?? const <(double, double)>[]) {
      canvas.drawCircle(p(t, x), 5, Paint()..color = color);
      canvas.drawCircle(
          p(t, x),
          5,
          Paint()
            ..color = kBg
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5);
    }
  }

  void _text(Canvas canvas, String s, Offset center, {Color color = kMuted}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: mono(size: 11, color: color)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(XtPainter old) =>
      old.tMax != tMax ||
      old.points.length != points.length ||
      old.fit != fit ||
      old.teamFit != teamFit;
}
