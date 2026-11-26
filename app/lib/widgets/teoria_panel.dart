import 'package:flutter/material.dart';

import '../theme.dart';

class TeoriaPanel extends StatelessWidget {
  const TeoriaPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5);
    Widget p(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: body));
    Widget f(String t) => Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: kBg,
            border: Border.all(color: kBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(t, style: mono(size: 15, color: kAccent)),
        );

    return Material(
      color: kSurface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        minTileHeight: 56,
        title: const Text('Teoría', style: TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          p('El Movimiento Rectilíneo Uniforme (MRU) es el de un cuerpo que se '
              'mueve en línea recta con velocidad constante: la aceleración es '
              'cero (a = 0) y recorre desplazamientos iguales en tiempos iguales.'),
          f('x = x₀ + v·t'),
          p('En la gráfica posición-tiempo (x-t) el MRU es una recta, y su '
              'pendiente es la velocidad:'),
          f('v = Δx / Δt'),
          p('La incertidumbre de la velocidad se propaga a partir de la de la '
              'posición y la del tiempo:'),
          f('u(v) = v·√[(u(x)/x)² + (u(t)/t)²]'),
          p('con u(x) = 1 mm (resolución de la regla) y u(t) = desviación '
              'estándar / √3.'),
        ],
      ),
    );
  }
}
