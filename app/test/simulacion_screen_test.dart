import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mru_app/screens/simulacion_screen.dart';
import 'package:mru_app/theme.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('Simulación corre completa sin errores a $width px', (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      tester.view.physicalSize = Size(width, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(),
        home: const DefaultTabController(
            length: 2, child: Scaffold(body: SimulacionScreen())),
      ));
      await tester.sendKeyEvent(LogicalKeyboardKey.space); // Iniciar
      // El Stopwatch usa tiempo real: avanzar frames hasta que termine.
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 3800)));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('03.00 s'), findsOneWidget);
      expect(find.textContaining('pendiente = 0.100 m/s · R² = 1.0000'), findsOneWidget);
      for (final s in ['0.50', '1.00', '1.50', '2.00', '2.50', '3.00']) {
        expect(find.text(s), findsOneWidget, reason: 't = $s');
      }
      // 6 celdas v = 0.100 + la x = 0.100 de la fila de 10 cm.
      expect(find.text('0.100'), findsNWidgets(7));
    }, timeout: const Timeout(Duration(seconds: 60)));
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(),
      home: const DefaultTabController(
          length: 2, child: Scaffold(body: SimulacionScreen())),
    ));
  }

  Future<void> runToEnd(WidgetTester tester, int ms) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
  }

  testWidgets('con 0.20 m/s la pendiente sale 0.200', (tester) async {
    await pumpScreen(tester);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(0.20);
    await tester.pump();
    await runToEnd(tester, 2300);
    expect(find.text('01.50 s'), findsOneWidget);
    expect(find.textContaining('pendiente = 0.200 m/s'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('soltar en el 0: llega a 30 cm en 3.50 s, nota y R² menor', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.textContaining('los primeros 5 cm no son MRU'), findsOneWidget);
    await runToEnd(tester, 4200);
    expect(find.text('03.50 s'), findsOneWidget);
    expect(find.textContaining('R² = 1.0000'), findsNothing);
    expect(find.textContaining('R² = 0.9'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 60)));

  testWidgets('Pausar congela; R reinicia y limpia la tabla', (tester) async {
    await pumpScreen(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 1200)));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.sendKeyEvent(LogicalKeyboardKey.space); // Pausar
    await tester.pump();
    final frozen = find.textContaining(RegExp(r'^\d\d\.\d\d s$'));
    final before = tester.widget<Text>(frozen).data;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.widget<Text>(frozen).data, before);
    expect(find.text('0.50'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    expect(find.text('00.00 s'), findsOneWidget);
    expect(find.text('0.50'), findsNothing);
  }, timeout: const Timeout(Duration(seconds: 60)));
}
