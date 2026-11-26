import 'package:flutter/material.dart';

import '../theme.dart';
import 'reto_screen.dart';
import 'simulacion_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                color: kSurface,
                child: Text(
                  'Práctica de Física: MRU · Equipo 4 · ITS Saltillo',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const Material(
                color: kSurface,
                child: TabBar(
                  tabs: [
                    Tab(height: 56, text: 'Simulación'),
                    Tab(height: 56, text: 'Reto'),
                  ],
                ),
              ),
              const Expanded(
                child: TabBarView(
                  children: [SimulacionScreen(), RetoScreen()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
