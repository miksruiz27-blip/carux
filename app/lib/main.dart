import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/leaderboard.dart';
import 'theme.dart';

void main() => runApp(const MruApp());

class MruApp extends StatelessWidget {
  const MruApp({super.key, this.service});

  /// Inyectable para tests; por defecto el backend real.
  final LeaderboardService? service;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MRU · Equipo 4 · ITS Saltillo',
        debugShowCheckedModeBanner: false,
        // Textos del framework (lectores de pantalla, diálogos) en español.
        locale: const Locale('es', 'MX'),
        supportedLocales: const [Locale('es', 'MX'), Locale('es')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: buildTheme(),
        home: HomeScreen(service: service),
      );
}
