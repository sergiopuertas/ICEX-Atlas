import 'package:flutter/material.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';

/// Texto que se recorta a [trimLines] líneas con «…ver más», como en LinkedIn e Instagram.
/// Un texto largo ya no ocupa la pantalla entera en el feed.
class ExpandableText extends StatefulWidget {
  const ExpandableText(this.text, {this.style, this.trimLines = 5, super.key});

  final String text;
  final TextStyle? style;
  final int trimLines;

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final style = widget.style ?? DefaultTextStyle.of(context).style;
    if (_expanded) return Text(widget.text, style: style);
    return LayoutBuilder(
      builder: (context, c) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: widget.trimLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: c.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        if (!overflows) return Text(widget.text, style: style);
        return Semantics(
          button: true,
          hint: l.seeMore,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = true),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.text,
                  style: style,
                  maxLines: widget.trimLines,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  l.seeMore,
                  style: style.copyWith(
                    color: IcexColors.mutedForeground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
