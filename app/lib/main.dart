import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme.dart';

void main() => runApp(const MruApp());

class MruApp extends StatelessWidget {
  const MruApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'MRU · Equipo 4 · ITS Saltillo',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const HomeScreen(),
      );
}
