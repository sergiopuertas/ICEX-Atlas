import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/shared/widgets/common.dart';

/// Elementos de marca de la portada, reutilizados en toda la app: degradado rojo ICEX,
/// globo de puntos con conexiones, barra amarilla y «hoja» blanca de esquinas redondeadas.

/// Degradado rojo de cabeceras. Empieza en el mismo rojo que la barra superior para que
/// barra y cabecera se vean como una sola pieza.
const icexHeroGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomRight,
  colors: [IcexColors.primary, Color(0xFFB00414), Color(0xFF7E0310)],
  stops: [0, 0.55, 1],
);

/// Barra amarilla corta sobre los títulos.
class AccentBar extends StatelessWidget {
  const AccentBar({super.key, this.width = 44});

  final double width;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 5,
    decoration: BoxDecoration(color: IcexColors.accent, borderRadius: BorderRadius.circular(4)),
  );
}

/// Logotipo sobre una pastilla blanca (el logo es rojo y no se ve sobre el degradado).
class LogoBadge extends StatelessWidget {
  const LogoBadge({super.key, this.height = 26, this.shadow = true});

  final double height;
  final bool shadow;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: height * 0.5, vertical: height * 0.36),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(height * 0.55),
      boxShadow: shadow
          ? const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))]
          : null,
    ),
    child: IcexLogo(height: height),
  );
}

/// Cabecera roja de las pantallas principales: barra amarilla, título y subtítulo en
/// blanco, contenido opcional debajo (buscador, compositor…) y el borde superior de la
/// «hoja» donde empieza el contenido, como en la portada.
class HeroHeader extends StatelessWidget {
  const HeroHeader({
    required this.title,
    this.subtitle,
    this.bottom,
    this.sheetColor = IcexColors.page,
    this.showSheetEdge = true,
    super.key,
  });

  /// Sin el borde de la hoja (el mapa dibuja sus propias esquinas redondeadas).
  final bool showSheetEdge;

  final String title;
  final String? subtitle;
  final Widget? bottom;

  /// Color de la hoja que empieza debajo (el fondo de la pantalla).
  final Color sheetColor;

  static const _lip = 22.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: icexHeroGradient),
      child: Stack(
        children: [
          const Positioned.fill(
            child: ExcludeSemantics(child: CustomPaint(painter: GlobePainter.header())),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AccentBar(width: 36),
                    const SizedBox(height: 10),
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: t.headlineMedium?.copyWith(color: Colors.white, height: 1.15),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: t.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: 0.88)),
                      ),
                    ],
                    if (bottom != null) ...[const SizedBox(height: 16), bottom!],
                  ],
                ),
              ),
              if (showSheetEdge)
                Container(
                  height: _lip,
                  decoration: BoxDecoration(
                    color: sheetColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(_lip + 2)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Globo de puntos con arcos de conexión (dibujo propio, decorativo): la red repartida
/// por el mundo. `GlobePainter.header` es una versión más discreta para las cabeceras.
class GlobePainter extends CustomPainter {
  const GlobePainter({
    this.centerX = 0.92,
    this.centerY = 0.30,
    this.radiusFactor = 0.62,
    this.minRadius = 220,
    this.opacity = 1,
    this.arcs = 7,
  });

  const GlobePainter.header()
    : centerX = 0.98,
      centerY = 0.05,
      radiusFactor = 0.5,
      minRadius = 150,
      opacity = 0.7,
      arcs = 3;

  final double centerX;
  final double centerY;
  final double radiusFactor;
  final double minRadius;
  final double opacity;
  final int arcs;

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.max<double>(size.width * radiusFactor, minRadius);
    final center = Offset(size.width * centerX, size.height * centerY);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.12 * opacity);

    canvas.drawCircle(center, r, line);
    for (var i = 1; i <= 4; i++) {
      final w = r * 2 * math.cos(i * math.pi / 10);
      canvas.drawOval(Rect.fromCenter(center: center, width: w, height: r * 2), line);
    }
    for (var i = -3; i <= 3; i++) {
      final y = center.dy + r * math.sin(i * math.pi / 8);
      final half = r * math.cos(i * math.pi / 8);
      canvas.drawLine(Offset(center.dx - half, y), Offset(center.dx + half, y), line);
    }

    final dot = Paint()..color = Colors.white.withValues(alpha: 0.35 * opacity);
    final rnd = math.Random(51);
    final points = <Offset>[];
    for (var i = 0; i < 70; i++) {
      final lat = (rnd.nextDouble() - 0.5) * math.pi * 0.9;
      final lon = (rnd.nextDouble() - 0.5) * math.pi;
      final p = Offset(
        center.dx + r * math.cos(lat) * math.sin(lon),
        center.dy - r * math.sin(lat),
      );
      points.add(p);
      canvas.drawCircle(p, 1.6 + rnd.nextDouble() * 1.4, dot);
    }

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = IcexColors.accent.withValues(alpha: 0.6 * opacity);
    final hub = Paint()..color = IcexColors.accent.withValues(alpha: opacity);
    bool visible(Offset p) => p.dx >= 0 && p.dy >= 0 && p.dx <= size.width && p.dy <= size.height;
    var drawn = 0;
    for (var i = 0; i < points.length && drawn < arcs; i++) {
      final a = points[i];
      if (!visible(a)) continue;
      for (var j = i + 1; j < points.length; j++) {
        final b = points[j];
        final d = (b - a).distance;
        if (!visible(b) || d < r * 0.25 || d > r * 0.55) continue;
        final mid = Offset.lerp(a, b, 0.5)!;
        var normal = Offset(-(b.dy - a.dy), b.dx - a.dx) / d;
        if (normal.dy > 0) normal = -normal;
        final ctrl = mid + normal * (d * 0.35);
        canvas
          ..drawPath(
            Path()
              ..moveTo(a.dx, a.dy)
              ..quadraticBezierTo(ctrl.dx, ctrl.dy, b.dx, b.dy),
            arc,
          )
          ..drawCircle(a, 2.5, hub)
          ..drawCircle(b, 2.5, hub);
        drawn++;
        i += 4;
        break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant GlobePainter old) =>
      old.centerX != centerX ||
      old.centerY != centerY ||
      old.radiusFactor != radiusFactor ||
      old.opacity != opacity ||
      old.arcs != arcs;
}
