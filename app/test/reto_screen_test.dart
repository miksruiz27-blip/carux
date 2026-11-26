import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mru_app/screens/reto_screen.dart';
import 'package:mru_app/services/leaderboard.dart';
import 'package:mru_app/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeApi implements LeaderboardService {
  var fetches = 0;
  final submitted = <List<List<double?>>>[];
  String? joined;

  @override
  Future<JoinResult> join(String name) async {
    joined = name;
    return JoinResult({'sessionId': 1, 'displayName': name, 'attemptsLeft': 1});
  }

  @override
  Future<AttemptResult> submit(String name, List<List<double?>> rounds) async {
    submitted.add(rounds);
    throw ApiException(409, 'sin_intentos');
  }

  @override
  Future<Leaderboard> fetch(String? name) async {
    fetches++;
    return Leaderboard({
      'sessionId': 1,
      'top': [],
      'me': null,
      'recent': [],
      'players': 0,
    });
  }

  @override
  Future<int> reset(String pin) async => 2;
}

Future<FakeApi> pumpReto(WidgetTester tester, {double width = 1280}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = FakeApi();
  await tester.pumpWidget(MaterialApp(
    theme: buildTheme(),
    home: DefaultTabController(
      length: 2,
      initialIndex: 1,
      child: Scaffold(
        body: Column(children: [
          const TabBar(tabs: [Tab(text: 'Simulación'), Tab(text: 'Reto')]),
          Expanded(child: TabBarView(children: [const SizedBox(), RetoScreen(service: api)])),
        ]),
      ),
    ),
  ));
  await tester.pump();
  return api;
}

void main() {
  testWidgets('polling cada 3 s solo con la pestaña Reto visible', (tester) async {
    final api = await pumpReto(tester);
    final start = api.fetches;
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(api.fetches, start + 2);

    await tester.tap(find.text('Simulación'));
    await tester.pumpAndSettle();
    final paused = api.fetches;
    await tester.pump(const Duration(seconds: 9));
    expect(api.fetches, paused, reason: 'pausado fuera de la pestaña');

    await tester.tap(find.text('Reto'));
    await tester.pumpAndSettle();
    expect(api.fetches, greaterThan(paused), reason: 'refresca al volver');
  });

  testWidgets('nombre inválido no llama al server', (tester) async {
    final api = await pumpReto(tester);
    await tester.enterText(find.byType(TextField), ' a ');
    await tester.tap(find.text('Entrar'));
    await tester.pump();
    expect(find.text('El nombre debe tener de 2 a 16 caracteres.'), findsOneWidget);
    expect(api.joined, isNull);
  });

  for (final width in [390.0, 1280.0]) {
    testWidgets('intento completo a $width px: 3 rondas, envío y 409', (tester) async {
      final api = await pumpReto(tester, width: width);
      await tester.enterText(find.byType(TextField), '  Ana   Luisa ');
      await tester.tap(find.text('Entrar'));
      await tester.pump();
      expect(api.joined, 'Ana Luisa');
      expect(find.text('1 intento restante'), findsOneWidget, reason: 'lo dice el server');

      await tester.tap(find.text('Comenzar intento'));
      await tester.pump();
      expect(find.textContaining('¡Prepárate!'), findsOneWidget);

      // Tiempo real (Stopwatch): avanzar frames hasta acabar las 3 rondas.
      // Un toque con espacio por ronda, cuando la pantalla dice que ya arrancó
      // (no por iteraciones: con la máquina cargada el reloj real se desfasa).
      final stop = DateTime.now().add(const Duration(seconds: 40));
      while (api.submitted.isEmpty && DateTime.now().isBefore(stop)) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
        if (find.textContaining('· marca 0/6').evaluate().isNotEmpty) {
          await tester.sendKeyEvent(LogicalKeyboardKey.space);
          await tester.pump();
        }
      }
      await tester.pump();
      expect(api.submitted, hasLength(1));
      final rounds = api.submitted.single;
      expect(rounds, hasLength(3));
      for (final r in rounds) {
        expect(r, hasLength(6));
        expect(r.where((t) => t != null), hasLength(1), reason: 'un toque por ronda');
      }
      expect(find.text('PUNTAJE'), findsOneWidget);
      expect(find.text('Ya usaste tus 3 intentos en esta sesión'), findsOneWidget);
      expect(find.text('Sin intentos restantes'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(seconds: 90)));
  }
}
