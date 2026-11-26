// Revisión contra CLAUDE.md: botones ≥ 48×48 y textos del framework en español.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mru_app/main.dart';
import 'package:mru_app/services/leaderboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Offline implements LeaderboardService {
  @override
  Future<JoinResult> join(String name) async => JoinResult({'sessionId': 1, 'displayName': name, 'attemptsLeft': 3});
  @override
  Future<AttemptResult> submit(String name, List<List<double?>> rounds) => throw OfflineException();
  @override
  Future<Leaderboard> fetch(String? name) => throw OfflineException();
  @override
  Future<int> reset(String pin) => throw OfflineException();
}

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final width in [390.0, 1280.0]) {
      testWidgets('controles ≥ 48×48 en $platform a $width px', (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        SharedPreferences.setMockInitialValues({'nombre': 'Ana'});
        debugDefaultTargetPlatformOverride = platform;
        tester.view.physicalSize = Size(width, 3000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MruApp(service: _Offline()));
        await tester.pump();

        void check(String where) {
          final targets = [
            ...find.byWidgetPredicate((w) => w is ButtonStyleButton || w is IconButton).evaluate(),
            ...find.byType(Tab).evaluate(),
            ...find.byType(SwitchListTile).evaluate(), // toda la fila es el área táctil
          ];
          expect(targets, isNotEmpty);
          for (final e in targets) {
            final size = tester.getSize(find.byWidget(e.widget));
            expect(size.width >= 48 && size.height >= 48, isTrue,
                reason: '$where: ${e.widget.runtimeType} mide $size');
          }
        }

        check('Simulación');
        await tester.tap(find.text('Reto'));
        await tester.pumpAndSettle();
        check('Reto (nombre)');
        expect(find.text('Ana'), findsWidgets); // entró con el nombre guardado
        check('Reto (listo)');
        await tester.tap(find.byTooltip('Reiniciar tabla'));
        await tester.pumpAndSettle();
        check('Diálogo PIN');

        // Textos del framework en español (lectores de pantalla, barreras de diálogos…).
        final l = MaterialLocalizations.of(tester.element(find.text('Reiniciar tabla').last));
        expect(l.modalBarrierDismissLabel, 'Descartar');
        debugDefaultTargetPlatformOverride = null;
      });
    }
  }
}
