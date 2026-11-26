import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mru_app/services/leaderboard.dart';
import 'package:mru_app/theme.dart';
import 'package:mru_app/widgets/marcador.dart';
import 'package:shared_preferences/shared_preferences.dart';

final now = DateTime.now().toUtc();
Map<String, dynamic> boardJson({int meRank = 23, List<Map<String, dynamic>>? top}) => {
      'sessionId': 1,
      'top': top ??
          [
            for (var i = 1; i <= 10; i++)
              {'rank': i, 'displayName': 'Jugador $i', 'score': i * 0.01, 'stars': 5}
          ],
      'me': {'rank': meRank, 'bestScore': 0.214, 'attemptsLeft': 1},
      'recent': [
        {'type': 'joined', 'displayName': 'Ana', 'rank': null, 'createdAt': now.subtract(const Duration(seconds: 10)).toIso8601String()},
        {'type': 'finished', 'displayName': 'Luis', 'rank': 4, 'createdAt': now.subtract(const Duration(minutes: 2)).toIso8601String()},
      ],
      'players': 14,
      'serverTime': now.toIso8601String(),
    };

class FakeService implements LeaderboardService {
  var online = true;
  final submitted = <List<List<double?>>>[];
  ApiException? reject;

  @override
  Future<AttemptResult> submit(String name, List<List<double?>> rounds) async {
    if (!online) throw OfflineException();
    if (reject != null) throw reject!;
    submitted.add(rounds);
    return AttemptResult({'score': 0.2, 'stars': 3, 'rank': 2, 'bestScore': 0.2, 'attemptsLeft': 2});
  }

  @override
  Future<JoinResult> join(String name) async => throw UnimplementedError();
  @override
  Future<Leaderboard> fetch(String? name) async => throw UnimplementedError();
  @override
  Future<int> reset(String pin) async => throw UnimplementedError();
}

void main() {
  group('ApiLeaderboardService', () {
    test('parsea el marcador y manda el nombre', () async {
      late Uri seen;
      final api = ApiLeaderboardService(
        base: 'http://x/api',
        client: MockClient((r) async {
          seen = r.url;
          return http.Response(jsonEncode(boardJson()), 200);
        }),
      );
      final b = await api.fetch('José');
      expect(seen.toString(), 'http://x/api/leaderboard?name=Jos%C3%A9');
      expect([b.top.length, b.me!.rank, b.me!.bestScore, b.players], [10, 23, 0.214, 14]);
      expect(b.recent.map((e) => e.text), ['Ana entró', 'Luis terminó #4']);
    });

    test('409 → ApiException(sin_intentos); sin red → OfflineException', () async {
      final api409 = ApiLeaderboardService(
          base: 'http://x/api',
          client: MockClient((_) async => http.Response('{"error":"sin_intentos"}', 409)));
      expect(() => api409.submit('Ana', []),
          throwsA(isA<ApiException>().having((e) => e.code, 'code', 'sin_intentos')));
      final down = ApiLeaderboardService(
          base: 'http://x/api', client: MockClient((_) async => throw http.ClientException('sin red')));
      expect(() => down.fetch(null), throwsA(isA<OfflineException>()));
      final proxy = ApiLeaderboardService(
          base: 'http://x/api', client: MockClient((_) async => http.Response('<html>502', 502)));
      expect(() => proxy.fetch(null), throwsA(isA<OfflineException>()));
    });

    test('reset manda el PIN en el header', () async {
      final api = ApiLeaderboardService(
        base: 'http://x/api',
        client: MockClient((r) async => r.headers['X-Admin-Pin'] == '1234'
            ? http.Response('{"sessionId":7}', 200)
            : http.Response('{"error":"pin_incorrecto"}', 401)),
      );
      expect(await api.reset('1234'), 7);
      expect(() => api.reset('0'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)));
    });
  });

  testWidgets('Outbox: sin red guarda el intento y reintenta cada 5 s', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = LocalStore();
    await store.load();
    final fake = FakeService()..online = false;
    AttemptResult? later;
    final box = Outbox(fake, store, onResult: (r) => later = r, onRejected: (_) {});
    final rounds = [
      [0.5, 1.0, null, null, null, null]
    ];
    expect(await box.submit('Ana', rounds), isNull);
    expect(store.pending.single['name'], 'Ana');

    await tester.pump(const Duration(seconds: 5)); // sigue sin red
    expect(box.pendingCount, 1);

    fake.online = true;
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(later!.rank, 2);
    expect(fake.submitted.single, rounds);
    expect(store.pending, isEmpty);
    box.dispose();
  });

  testWidgets('Outbox: un 409 en el reintento se descarta y avisa', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pendientes': jsonEncode([
        {'name': 'Ana', 'rounds': [[0.5]]}
      ])
    });
    final store = LocalStore();
    await store.load();
    ApiException? err;
    final box = Outbox(FakeService()..reject = ApiException(409, 'sin_intentos'), store,
        onResult: (_) {}, onRejected: (e) => err = e)
      ..resume();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    expect(err!.code, 'sin_intentos');
    expect(store.pending, isEmpty);
    box.dispose();
  });

  Future<void> pumpBoard(WidgetTester tester, Map<String, dynamic> json, {bool offline = false}) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
          body: SingleChildScrollView(
              child: Marcador(board: Leaderboard(json), offline: offline, onReset: () {}))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Marcador: top 10, fila "Tú" fuera del top, meta, feed y jugadores', (tester) async {
    await pumpBoard(tester, boardJson(), offline: true);
    expect(find.text('Jugador 10'), findsOneWidget);
    expect(find.text('Tú: #23 · 0.214 s'), findsOneWidget);
    expect(find.text('Meta Equipo 4'), findsOneWidget);
    expect(find.text('Ana entró'), findsOneWidget);
    expect(find.text('Luis terminó #4'), findsOneWidget);
    expect(find.text('hace 10 s'), findsOneWidget);
    expect(find.text('hace 2 min'), findsOneWidget);
    expect(find.text('14 jugadores'), findsOneWidget);
    expect(find.text('sin conexión'), findsOneWidget);
    expect(find.byTooltip('Reiniciar tabla'), findsOneWidget);
    // La meta (0.012) queda entre el #1 (0.010) y el #2 (0.020).
    double y(String s) => tester.getTopLeft(find.text(s)).dy;
    expect(y('Jugador 1') < y('Meta Equipo 4') && y('Meta Equipo 4') < y('Jugador 2'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Marcador: dentro del top 10 no hay fila extra; las filas se mueven al cambiar', (tester) async {
    await pumpBoard(tester, boardJson(meRank: 3));
    expect(find.textContaining('Tú:'), findsNothing);
    final before = tester.getTopLeft(find.text('Jugador 3')).dy;
    // Jugador 3 pasa al primer lugar.
    final top = [
      {'rank': 1, 'displayName': 'Jugador 3', 'score': 0.001, 'stars': 5},
      {'rank': 2, 'displayName': 'Jugador 1', 'score': 0.01, 'stars': 5},
    ];
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
          body: SingleChildScrollView(
              child: Marcador(board: Leaderboard(boardJson(top: top)), offline: false, onReset: () {}))),
    ));
    await tester.pump(const Duration(milliseconds: 200));
    final mid = tester.getTopLeft(find.text('Jugador 3')).dy;
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.text('Jugador 3')).dy;
    expect(after < mid && mid < before, isTrue, reason: 'se desliza hacia arriba');
  });
}
