import 'package:flutter/material.dart';

import '../widgets/panel.dart';

class RetoScreen extends StatelessWidget {
  const RetoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageLayout(
      scene: Panel(title: 'Reto: ¡MARCA!', height: 220, child: Placeholder()),
      left: Panel(title: 'Tus tiempos', height: 300, child: Placeholder()),
      right: Panel(title: 'Marcador', height: 300, child: Placeholder()),
    );
  }
}
