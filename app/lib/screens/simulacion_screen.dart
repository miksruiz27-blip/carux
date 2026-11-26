import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../physics/mru.dart';
import '../theme.dart';
import '../widgets/panel.dart';
import '../widgets/teoria_panel.dart';
import '../widgets/track_scene.dart';
import '../widgets/xt_chart.dart';

class SimulacionScreen extends StatefulWidget {
  const SimulacionScreen({super.key});

  @override
  State<SimulacionScreen> createState() => _SimulacionScreenState();
}

class _SimulacionScreenState extends State<SimulacionScreen>
    with SingleTickerProviderStateMixin {
  final _clock = SimClock();
  late final Ticker _ticker = createTicker(_onTick);
  var _motion = const CartMotion();
  late var _fit = simFit(_motion); // se calcula una vez por configuración
  var _compare = false;

  double get _t => _clock.seconds;

  // El reloj corre un poco después de llegar al 30 para que se apague el
  // destello de la última marca.
  bool get _finished => _t >= _motion.endTime + kFlashSeconds;
  bool get _reached30 => _motion.crossed(_motion.xEnd, _t);

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration _) {
    if (_finished) {
      _clock.pause();
      _ticker.stop();
    }
    setState(() {});
  }

  void _start() {
    if (_finished) return;
    _clock.start();
    if (!_ticker.isActive) _ticker.start();
    setState(() {});
  }

  void _pause() {
    _clock.pause();
    _ticker.stop();
    setState(() {});
  }

  void _reset() {
    _clock.reset();
    _ticker.stop();
    setState(() {});
  }

  void _setMotion(CartMotion m) {
    _motion = m;
    _fit = simFit(m);
    _reset();
  }

  bool _onKey(KeyEvent e) {
    // Solo en esta pestaña, solo al presionar (no repeticiones).
    if (e is! KeyDownEvent || DefaultTabController.of(context).index != 0) {
      return false;
    }
    if (e.logicalKey == LogicalKeyboardKey.space) {
      _clock.running ? _pause() : _start();
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.keyR) {
      _reset();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final crossed = [
      for (final x in kMarks)
        if (_motion.crossed(x, t)) (_motion.crossingTime(x), x),
    ];
    return PageLayout(
      scene: Panel(title: 'Escena', child: _sceneAndControls(t)),
      left: Panel(title: 'Tabla de datos', child: _table(crossed)),
      right: Panel(title: 'Gráfica x-t', child: _chart(crossed)),
      footer: const TeoriaPanel(),
    );
  }

  Widget _sceneAndControls(double t) {
    final running = _clock.running;
    final stopped = !running;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TrackScene(motion: _motion, t: t),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: running || _finished ? null : _start,
              icon: const Icon(Icons.play_arrow),
              label: Text(t > 0 && !_finished ? 'Reanudar' : 'Iniciar'),
            ),
            OutlinedButton.icon(
              onPressed: running ? _pause : null,
              icon: const Icon(Icons.pause),
              label: const Text('Pausar'),
            ),
            OutlinedButton.icon(
              onPressed: t > 0 ? _reset : null,
              icon: const Icon(Icons.replay),
              label: const Text('Reiniciar'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Atajos: Espacio = Iniciar/Pausar · R = Reiniciar',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted)),
        const SizedBox(height: 12),
        Row(
          children: [
            Text('v', style: mono(size: 15, color: kMuted)),
            Expanded(
              child: Slider(
                value: _motion.v,
                min: 0.05,
                max: 0.20,
                divisions: 15,
                label: '${_motion.v.toStringAsFixed(2)} m/s',
                onChanged: stopped
                    ? (v) => _setMotion(CartMotion(
                        v: (v * 100).round() / 100, fromZero: _motion.fromZero))
                    : null,
              ),
            ),
            Text('${_motion.v.toStringAsFixed(2)} m/s',
                style: mono(size: 15, color: kAccent, weight: FontWeight.w600)),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Soltar el carrito en el 0'),
          value: _motion.fromZero,
          onChanged: stopped
              ? (on) => _setMotion(CartMotion(v: _motion.v, fromZero: on))
              : null,
        ),
        if (_motion.fromZero)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2410),
              border: Border.all(color: const Color(0xFF6B5A1E)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Al soltarlo en el 0, el carrito tarda en alcanzar su velocidad: '
              'los primeros 5 cm no son MRU. Por eso en la práctica lo liberamos '
              'antes del 0 y solo medimos el tramo con velocidad constante.',
              style: TextStyle(color: Color(0xFFF2D98A), height: 1.4),
            ),
          ),
      ],
    );
  }

  Widget _table(List<(double, double)> crossed) {
    final head = mono(size: 12, color: kMuted, weight: FontWeight.w600);
    final cell = mono(size: 14);
    TableRow row(List<String> cells, TextStyle style) => TableRow(
          children: [
            for (final c in cells)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Text(c, style: style, textAlign: TextAlign.right),
              ),
          ],
        );
    return Table(
      border: const TableBorder(horizontalInside: BorderSide(color: kBorder)),
      children: [
        row(['cm', 'x (m)', 't (s)', 'v = x/t (m/s)'], head),
        for (final (t, x) in crossed.where((c) => c.$2 > 0))
          row([
            (x * 100).round().toString(),
            x.toStringAsFixed(3),
            t.toStringAsFixed(2),
            (x / t).toStringAsFixed(3),
          ], cell),
      ],
    );
  }

  Widget _chart(List<(double, double)> crossed) {
    final dur = _compare ? math.max(_motion.duration, kTeamTimes.last) : _motion.duration;
    final tMax = (dur / 0.5 - 1e-9).ceil() * 0.5; // eje hasta el siguiente 0.5 s
    final fit = _reached30 ? _fit : null;
    final body = Theme.of(context).textTheme.bodySmall;
    Widget legend(Color c, String s) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(s, style: mono(size: 13, color: c))),
          ]),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 260,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: XtPainter(
                tMax: tMax,
                points: crossed,
                fit: fit,
                teamPoints: _compare
                    ? [for (var i = 0; i < kMarks.length; i++) (kTeamTimes[i], kMarks[i])]
                    : null,
                teamFit: _compare ? teamFit : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (fit != null)
          legend(kAccent,
              'Simulación: pendiente = ${fit.slope.toStringAsFixed(3)} m/s · R² = ${fit.r2.toStringAsFixed(4)}')
        else
          Text('La recta de ajuste aparece al llegar a 30 cm.',
              style: body?.copyWith(color: kMuted)),
        if (_compare)
          legend(kTeam,
              'Equipo 4: pendiente = ${teamFit.slope.toStringAsFixed(3)} m/s · R² = ${teamFit.r2.toStringAsFixed(4)}'),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _compare = !_compare),
            icon: Icon(_compare ? Icons.visibility_off : Icons.compare_arrows),
            label: Text(_compare ? 'Ocultar nuestros datos' : 'Comparar con nuestros datos'),
          ),
        ),
      ],
    );
  }
}
