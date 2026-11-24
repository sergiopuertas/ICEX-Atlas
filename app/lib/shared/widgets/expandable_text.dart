import 'package:flutter/material.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';

/// Texto largo recortado a [trimLines] líneas con un botón claro «Leer más» debajo, y
/// «Mostrar menos» para volver a recogerlo. Tocar el propio texto recortado también lo
/// despliega.
///
/// La medición (¿cabe o no?) se hace una sola vez por ancho y texto, no en cada
/// reconstrucción, para que el scroll del feed no recalcule el texto de cada publicación.
class ExpandableText extends StatefulWidget {
  const ExpandableText(
    this.text, {
    this.style,
    this.trimLines = 6,
    this.fadeColor = IcexColors.card,
    super.key,
  });

  final String text;
  final TextStyle? style;
  final int trimLines;

  /// Color del fondo sobre el que va el texto (para el desvanecido de la última línea).
  final Color fadeColor;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;
  ({double width, String text, double scale, bool overflows})? _measured;

  bool _overflows(BuildContext context, TextStyle style, double width) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final m = _measured;
    if (m != null && m.width == width && m.text == widget.text && m.scale == scale) {
      return m.overflows;
    }
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: style),
      maxLines: widget.trimLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: width);
    final overflows = painter.didExceedMaxLines;
    painter.dispose();
    _measured = (width: width, text: widget.text, scale: scale, overflows: overflows);
    return overflows;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    return LayoutBuilder(
      builder: (context, c) {
        if (!_overflows(context, style, c.maxWidth)) return Text(widget.text, style: style);
        final toggle = Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('expandable-toggle'),
            onPressed: () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: IcexColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 4),
              minimumSize: const Size(48, 40),
              textStyle: const TextStyle(
                fontFamily: IcexTheme.body,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            iconAlignment: IconAlignment.end,
            icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            label: Text(_expanded ? l.showLess : l.readMore),
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_expanded)
              Text(widget.text, style: style)
            else
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = true),
                // La última línea se desvanece hacia el fondo: se ve que el texto sigue.
                // Es un degradado encima (no un ShaderMask, que añade una capa de
                // composición por publicación y encarece el scroll).
                child: Stack(
                  children: [
                    Text(
                      widget.text,
                      style: style,
                      maxLines: widget.trimLines,
                      overflow: TextOverflow.clip,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: (style.fontSize ?? 15) * (style.height ?? 1.3) * 1.2,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [widget.fadeColor.withValues(alpha: 0), widget.fadeColor],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            toggle,
          ],
        );
      },
    );
  }
}
