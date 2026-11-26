import 'package:flutter/material.dart';

import '../theme.dart';

/// Tarjeta con borde y título, estilo instrumento.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.title, required this.child, this.height});

  final String title;
  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    // Material (no Container con color) para que ListTile/ink se pinten bien.
    return Material(
      color: kSurface,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: kBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: mono(size: 12, color: kMuted, weight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(height: height, child: child),
        ],
      ),
      ),
    );
  }
}

/// Escena arriba; debajo [left] | [right] en >= 800 px, o todo apilado.
class PageLayout extends StatelessWidget {
  const PageLayout({
    super.key,
    required this.scene,
    required this.left,
    required this.right,
    this.footer,
  });

  final Widget scene, left, right;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 16, height: 16);
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= kWide;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                scene,
                gap,
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [Expanded(child: left), gap, Expanded(child: right)],
                  )
                else ...[left, gap, right],
                if (footer != null) ...[gap, footer!],
              ],
            ),
          ),
        ),
      );
    });
  }
}
