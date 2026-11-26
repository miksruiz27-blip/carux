import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../physics/mru.dart';
import '../physics/reto.dart';
import '../services/leaderboard.dart';
import '../theme.dart';
import '../widgets/marcador.dart';
import '../widgets/panel.dart';
import '../widgets/track_scene.dart';

/// Pausa antes de cada ronda (s) para prepararse.
const kLead = 1.5;
const kRetoTab = 1;

enum _Phase { name, ready, playing, done }

class RetoScreen extends StatefulWidget {
  const RetoScreen({super.key, this.service});

  /// Inyectable para tests; por defecto el backend real.
  final LeaderboardService? service;

  @override
  State<RetoScreen> createState() => _RetoScreenState();
}

class _RetoScreenState extends State<RetoScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late final LeaderboardService _service = widget.service ?? ApiLeaderboardService();
  final _store = LocalStore();
  late final _outbox = Outbox(_service, _store, onResult: _onSaved, onRejected: _onRejected);
  final _nameCtrl = TextEditingController();

  // Jugador.
  var _phase = _Phase.name;
  String? _name;
  String? _nameError;
  var _joining = false;
  int? _serverLeft; // lo que dice el server (manda)
  var _localUsed = 0; // respaldo si no hay red
  int? _sessionId;

  // Intento en curso.
  final _clock = SimClock();
  late final Ticker _ticker = createTicker(_onTick);
  static const _motion = CartMotion();
  var _round = 0;
  var _rounds = List.generate(kRounds, (_) => RoundTaps());
  AttemptScore? _result;
  AttemptResult? _saved;
  String? _saveMsg;

  // Marcador.
  Leaderboard? _board;
  var _offline = false;
  Timer? _poll;
  var _fetching = false;
  TabController? _tabs;
  var _appVisible = true;
  late final AppLifecycleListener _life;

  int get _attemptsLeft => _serverLeft ?? math.max(0, kMaxAttempts - _localUsed);

  // Tiempo desde la liberación del carrito en la ronda actual.
  double get _t => math.max(0, _clock.seconds - kLead);
  double get _chrono => _t - _motion.timeAt(0);

  @override
  bool get wantKeepAlive => true; // no perder el intento ni el marcador al cambiar de pestaña

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_onKey);
    _life = AppLifecycleListener(onStateChange: (s) {
      _appVisible = s == AppLifecycleState.resumed;
      _syncPolling();
    });
    _init();
  }

  Future<void> _init() async {
    await _store.load();
    _outbox.resume();
    if (_outbox.pendingCount > 0 && mounted) setState(() => _saveMsg = 'Guardando tu resultado...');
    final saved = _store.name;
    if (saved != null && mounted) {
      _nameCtrl.text = saved;
      await _join();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = DefaultTabController.maybeOf(context);
    if (tabs != _tabs) {
      _tabs?.removeListener(_syncPolling);
      _tabs = tabs?..addListener(_syncPolling);
      _syncPolling();
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _tabs?.removeListener(_syncPolling);
    _life.dispose();
    _poll?.cancel();
    _outbox.dispose();
    _ticker.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Marcador en vivo ──────────────────────────────────────────────────

  bool get _visible => _appVisible && (_tabs == null || _tabs!.index == kRetoTab);

  void _syncPolling() {
    if (_visible && _poll == null) {
      _refresh();
      _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    } else if (!_visible) {
      _poll?.cancel();
      _poll = null;
    }
  }

  Future<void> _refresh() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final b = await _service.fetch(_name);
      if (!mounted) return;
      setState(() {
        if (_sessionId != null && b.sessionId != _sessionId) _localUsed = 0; // reiniciaron la tabla
        _sessionId = b.sessionId;
        _board = b;
        _offline = false;
        if (b.me != null && _outbox.pendingCount == 0) _serverLeft = b.me!.attemptsLeft;
      });
    } catch (_) {
      if (mounted) setState(() => _offline = true); // se queda el último marcador
    } finally {
      _fetching = false;
    }
  }

  // ── Nombre ────────────────────────────────────────────────────────────

  Future<void> _join() async {
    final name = _nameCtrl.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.runes.length < 2 || name.runes.length > 16) {
      setState(() => _nameError = 'El nombre debe tener de 2 a 16 caracteres.');
      return;
    }
    setState(() {
      _joining = true;
      _nameError = null;
    });
    String? display;
    try {
      final r = await _service.join(name);
      display = r.displayName;
      _serverLeft = r.attemptsLeft;
      _sessionId = r.sessionId;
      _offline = false;
    } on ApiException catch (e) {
      _nameError = e.code == 'nombre_no_permitido' ? 'Ese nombre no está permitido.' : 'Nombre inválido.';
    } on OfflineException {
      display = name; // se juega igual; el server decide al enviar
      _serverLeft = null;
      _offline = true;
    }
    if (!mounted) return;
    setState(() {
      _joining = false;
      if (display == null) return;
      if (_store.name?.toLowerCase() != display.toLowerCase()) _store.best = null;
      _store.name = display;
      _name = display;
      _phase = _Phase.ready;
    });
    if (display != null) _refresh();
  }

  void _changeName() => setState(() {
        _phase = _Phase.name;
        _name = null;
        _serverLeft = null;
        _localUsed = 0;
        _result = null;
        _saved = null;
        _saveMsg = null;
      });

  // ── Intento ───────────────────────────────────────────────────────────

  void _start() {
    if (_attemptsLeft <= 0) return;
    setState(() {
      _phase = _Phase.playing;
      _round = 0;
      _rounds = List.generate(kRounds, (_) => RoundTaps());
      _result = null;
      _saved = null;
      _saveMsg = null;
    });
    _clock
      ..reset()
      ..start();
    _ticker.start();
  }

  void _tap() {
    if (_phase != _Phase.playing) return;
    if (_rounds[_round].tap(_chrono) != null) setState(() {});
  }

  void _onTick(Duration _) {
    if (_chrono >= kRoundEnd) {
      if (_round < kRounds - 1) {
        _round++;
        _clock
          ..reset()
          ..start();
      } else {
        _finish();
      }
    }
    setState(() {});
  }

  Future<void> _finish() async {
    _clock.pause();
    _ticker.stop();
    final rounds = [for (final r in _rounds) r.times];
    final s = scoreAttempt(rounds);
    _phase = _Phase.done;
    _result = s;
    _localUsed++;
    if (_serverLeft != null) _serverLeft = math.max(0, _serverLeft! - 1);
    final best = _store.best;
    if (best == null || s.score < best) _store.best = s.score;

    try {
      final r = await _outbox.submit(_name!, rounds);
      if (!mounted) return;
      if (r == null) {
        setState(() => _saveMsg = 'Guardando tu resultado...');
      } else {
        _onSaved(r);
      }
    } on ApiException catch (e) {
      _onRejected(e);
    }
  }

  void _onSaved(AttemptResult r) {
    if (!mounted) return;
    setState(() {
      _saved = r;
      _saveMsg = null;
      _serverLeft = r.attemptsLeft;
    });
    _refresh();
  }

  void _onRejected(ApiException e) {
    if (!mounted) return;
    setState(() {
      if (e.code == 'sin_intentos') {
        _saveMsg = 'Ya usaste tus 3 intentos en esta sesión';
        _serverLeft = 0;
      } else {
        _saveMsg = 'El servidor rechazó el intento (${e.code}).';
      }
    });
  }

  bool _onKey(KeyEvent e) {
    if (e is! KeyDownEvent || e.logicalKey != LogicalKeyboardKey.space) return false;
    if (_phase != _Phase.playing || !_visible) return false;
    _tap();
    return true;
  }

  // ── Reinicio de la tabla ──────────────────────────────────────────────

  Future<void> _askReset() async {
    final pin = await showDialog<String>(context: context, builder: (_) => const _PinDialog());
    if (pin == null || pin.isEmpty || !mounted) return;
    final msg = ScaffoldMessenger.of(context);
    String text;
    try {
      final id = await _service.reset(pin);
      text = 'Tabla reiniciada (sesión #$id).';
      _localUsed = 0;
      _refresh();
    } on ApiException catch (e) {
      text = switch (e.status) {
        401 => 'PIN incorrecto.',
        429 => 'Demasiados intentos fallidos. Espera 10 minutos.',
        503 => 'El reinicio está deshabilitado en el servidor.',
        _ => 'No se pudo reiniciar (${e.code}).',
      };
    } on OfflineException {
      text = 'Sin conexión: no se pudo reiniciar.';
    }
    msg.showSnackBar(SnackBar(content: Text(text)));
  }

  // ── UI ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return PageLayout(
      scene: Panel(title: 'Reto: ¡MARCA!', child: _phase == _Phase.name ? _nameForm() : _game()),
      left: Panel(title: 'Tus tiempos', child: _results()),
      right: Panel(
        title: 'Marcador',
        child: Marcador(board: _board, offline: _offline, onReset: _askReset),
      ),
    );
  }

  Widget _nameForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Toca ¡MARCA! (o la barra espaciadora) justo cuando la nariz del carrito '
            'cruce 5, 10, 15, 20, 25 y 30 cm. Son 3 rondas seguidas; gana quien tenga '
            'la menor diferencia promedio contra el tiempo real.'),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              maxLength: 16,
              enabled: !_joining,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _join(),
              decoration: InputDecoration(
                labelText: 'Tu nombre',
                errorText: _nameError,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 56,
            child: FilledButton(onPressed: _joining ? null : _join, child: const Text('Entrar')),
          ),
        ]),
      ],
    );
  }

  Widget _game() {
    final playing = _phase == _Phase.playing;
    final left = _attemptsLeft;
    final String status;
    if (playing) {
      status = _clock.seconds < kLead
          ? 'Ronda ${_round + 1} de $kRounds · ¡Prepárate!'
          : 'Ronda ${_round + 1} de $kRounds · marca ${_rounds[_round].count}/6';
    } else {
      status = left == 0 ? 'Sin intentos restantes' : '$left ${left == 1 ? 'intento restante' : 'intentos restantes'}';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(
            child: Text(_name ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          if (!playing) TextButton(onPressed: _changeName, child: const Text('Cambiar nombre')),
        ]),
        const SizedBox(height: 8),
        TrackScene(motion: _motion, t: playing ? _t : 0),
        const SizedBox(height: 12),
        Text(status, style: mono(size: 15, color: playing ? kAccent : kMuted, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        if (playing)
          SizedBox(
            height: 88,
            child: FilledButton(
              onPressed: _tap,
              style: FilledButton.styleFrom(
                textStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('¡MARCA!'),
            ),
          )
        else
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: left > 0 ? _start : null,
              icon: const Icon(Icons.play_arrow),
              label: Text(_phase == _Phase.done ? 'Otro intento' : 'Comenzar intento'),
            ),
          ),
        const SizedBox(height: 4),
        Text('Barra espaciadora = ¡MARCA!', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted)),
      ],
    );
  }

  Widget _results() {
    final head = mono(size: 12, color: kMuted, weight: FontWeight.w600);
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted);
    TableRow row(String label, List<String> cells, TextStyle style) => TableRow(children: [
          for (final c in [label, ...cells])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
              child: Text(c, style: style, textAlign: TextAlign.right),
            ),
        ]);
    String fmt(double? t) => t == null ? '—' : t.toStringAsFixed(2);
    final started = _phase == _Phase.playing || _phase == _Phase.done;
    final avg = [
      for (var i = 0; i < 6; i++)
        () {
          final hit = [for (final r in _rounds) ?r.times[i]];
          return hit.isEmpty ? null : hit.reduce((a, b) => a + b) / hit.length;
        }()
    ];
    final s = _result;
    // El dato en vivo del server manda; luego el último guardado; luego el local.
    final best = _board?.me?.bestScore ?? _saved?.bestScore ?? _store.best;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          border: const TableBorder(horizontalInside: BorderSide(color: kBorder)),
          columnWidths: const {0: FlexColumnWidth(1.4)},
          children: [
            row('cm', ['5', '10', '15', '20', '25', '30'], head),
            row('real', [for (final t in kRealTimes) t.toStringAsFixed(2)], mono(size: 13, color: kTeam)),
            for (var r = 0; r < kRounds; r++)
              row(
                'R${r + 1}',
                [
                  for (var i = 0; i < 6; i++)
                    !started || (_phase == _Phase.playing && r > _round) ? '' : fmt(_rounds[r].times[i])
                ],
                mono(size: 13, color: _phase == _Phase.playing && r == _round ? kAccent : kText),
              ),
            if (s != null) row('prom', [for (final t in avg) fmt(t)], mono(size: 13, weight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 16),
        if (s == null)
          Text(
            started
                ? 'Toca cuando la nariz cruce cada marca.'
                : 'Tu puntaje es la diferencia promedio |t tuyo − t real| en los 18 toques. '
                    'Una marca sin tocar cuenta 1.000 s. Menor gana.',
            style: small,
          )
        else ...[
          Text('PUNTAJE', style: head),
          Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 12, children: [
            Text('${s.score.toStringAsFixed(3)} s', style: mono(size: 36, color: kAccent, weight: FontWeight.w700)),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(stars(s.stars), style: const TextStyle(color: kAccent, fontSize: 22)),
            ),
          ]),
          const SizedBox(height: 8),
          _stat('Meta Equipo 4',
              '${kTeamGoal.toStringAsFixed(3)} s ${s.score <= kTeamGoal ? '· ¡la venciste!' : ''}', kTeam),
          _stat(
              'Reacción promedio',
              s.reactionAvg == null
                  ? '—'
                  : '${s.reactionAvg! >= 0 ? '+' : ''}${s.reactionAvg!.toStringAsFixed(3)} s '
                      '(${s.reactionAvg! > 0 ? 'tarde' : s.reactionAvg! < 0 ? 'temprano' : 'exacto'})'),
          _stat('Error de velocidad', s.velErrorPct == null ? '—' : '${s.velErrorPct!.toStringAsFixed(1)} %'),
          if (_saved != null) _stat('Posición', '#${_saved!.rank} en el marcador', kAccent),
        ],
        if (best != null) _stat('Tu mejor', '${best.toStringAsFixed(3)} s'),
        if (_saveMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(children: [
              if (_saveMsg!.startsWith('Guardando'))
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              Expanded(child: Text(_saveMsg!, style: const TextStyle(color: Color(0xFFF2D98A)))),
            ]),
          ),
      ],
    );
  }

  Widget _stat(String label, String value, [Color color = kText]) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: const TextStyle(color: kMuted))),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: mono(size: 14, color: color))),
        ]),
      );
}

/// Pide el PIN. El PIN solo vive en este diálogo; no se guarda.
class _PinDialog extends StatefulWidget {
  const _PinDialog();

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Reiniciar tabla'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Borra el marcador y abre una sesión nueva. Solo para el profesor o el equipo.'),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            autofillHints: const <String>[],
            enableSuggestions: false,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'PIN de admin', border: OutlineInputBorder()),
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('Reiniciar')),
        ],
      );
}
