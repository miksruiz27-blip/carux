import 'package:flutter/material.dart';

import '../physics/reto.dart';
import '../services/leaderboard.dart';
import '../theme.dart';

String stars(int n) => '★' * n + '☆' * (5 - n);

String relativeTime(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  if (s < 60) return 'hace $s s';
  if (s < 3600) return 'hace ${s ~/ 60} min';
  return 'hace ${s ~/ 3600} h';
}

/// Marcador global: top 10 con la meta del Equipo 4, tu posición, el feed y
/// el candado de reinicio. Solo dibuja; el polling vive en la pantalla.
class Marcador extends StatelessWidget {
  const Marcador({super.key, required this.board, required this.offline, required this.onReset});

  final Leaderboard? board;
  final bool offline;
  final VoidCallback onReset;

  static const rowH = 44.0;

  @override
  Widget build(BuildContext context) {
    final b = board;
    final small = Theme.of(context).textTheme.bodySmall?.copyWith(color: kMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text(b == null ? '' : '${b.players} ${b.players == 1 ? 'jugador' : 'jugadores'}',
              style: mono(size: 13, color: kMuted)),
          const Spacer(),
          if (offline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF6B5A1E)), borderRadius: BorderRadius.circular(99)),
              child: Text('sin conexión', style: mono(size: 12, color: const Color(0xFFF2D98A))),
            ),
        ]),
        const SizedBox(height: 8),
        if (b == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(offline ? 'No se pudo cargar el marcador.' : 'Cargando marcador…', style: small),
          )
        else ...[
          _table(b),
          if (b.me?.rank case final r? when r > 10)
            _row(
              key: const ValueKey('me'),
              highlight: true,
              child: Text('Tú: #$r · ${b.me!.bestScore!.toStringAsFixed(3)} s',
                  style: mono(size: 14, color: kAccent, weight: FontWeight.w600)),
            ),
          if (b.top.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Nadie ha terminado un intento todavía. ¡Sé el primero!', style: small),
            ),
          const SizedBox(height: 20),
          Text('AHORA MISMO', style: mono(size: 12, color: kMuted, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (b.recent.isEmpty) Text('Sin actividad.', style: small),
          for (final e in b.recent)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                Icon(e.type == 'finished' ? Icons.flag : Icons.login, size: 16,
                    color: e.type == 'finished' ? kAccent : kMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(e.text, overflow: TextOverflow.ellipsis)),
                Text(relativeTime(DateTime.now().add(b.clockSkew).difference(e.createdAt)),
                    style: mono(size: 12, color: kMuted)),
              ]),
            ),
        ],
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            tooltip: 'Reiniciar tabla',
            onPressed: onReset,
            icon: const Icon(Icons.lock_outline, size: 18, color: kBorder),
          ),
        ),
      ],
    );
  }

  /// Filas en un Stack con AnimatedPositioned: cuando alguien sube o baja,
  /// su fila se desliza a la nueva posición.
  Widget _table(Leaderboard b) {
    final myRank = b.me?.rank;
    // La meta se ordena como un jugador más: queda debajo de quien la venció.
    final items = <(String, Widget)>[];
    var goalPlaced = false;
    Widget goal() => _row(
          key: const ValueKey('meta'),
          dashed: true,
          child: Row(children: [
            const SizedBox(width: 36),
            Expanded(child: Text('Meta Equipo 4', style: TextStyle(color: kTeam))),
            Text('${kTeamGoal.toStringAsFixed(3)} s', style: mono(size: 14, color: kTeam)),
            const SizedBox(width: 96),
          ]),
        );
    for (final e in b.top) {
      if (!goalPlaced && e.score > kTeamGoal) {
        items.add(('meta', goal()));
        goalPlaced = true;
      }
      final mine = e.rank == myRank;
      items.add((
        'p:${e.displayName.toLowerCase()}',
        _row(
          key: ValueKey('p:${e.displayName.toLowerCase()}'),
          highlight: mine,
          child: Row(children: [
            SizedBox(
                width: 36,
                child: Text('#${e.rank}', style: mono(size: 14, color: mine ? kAccent : kMuted))),
            Expanded(
                child: Text(e.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: mine ? FontWeight.w700 : FontWeight.w400))),
            Text('${e.score.toStringAsFixed(3)} s', style: mono(size: 14, color: mine ? kAccent : kText)),
            SizedBox(
                width: 96,
                child: Text(stars(e.stars),
                    textAlign: TextAlign.right, style: const TextStyle(color: kAccent, fontSize: 14))),
          ]),
        ),
      ));
    }
    if (!goalPlaced) items.add(('meta', goal()));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: items.length * rowH,
      child: Stack(children: [
        for (var i = 0; i < items.length; i++)
          AnimatedPositioned(
            key: ValueKey(items[i].$1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeInOutCubic,
            top: i * rowH,
            left: 0,
            right: 0,
            height: rowH,
            child: _FadeIn(child: items[i].$2),
          ),
      ]),
    );
  }

  Widget _row({required Key key, required Widget child, bool highlight = false, bool dashed = false}) =>
      Container(
        key: key,
        height: rowH,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: highlight ? kAccent.withValues(alpha: 0.10) : null,
          border: Border(
            left: BorderSide(color: highlight ? kAccent : Colors.transparent, width: 3),
            bottom: BorderSide(color: dashed ? kTeam.withValues(alpha: 0.5) : kBorder),
          ),
        ),
        child: child,
      );
}

/// Las filas nuevas aparecen con un fundido.
class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 400),
        builder: (_, v, c) => Opacity(opacity: v, child: c),
        child: child,
      );
}
