import 'package:flutter/material.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';

/// Badge redondeado de fase: Fase 0 · Fase I · Fase II · ACTIVO.
class PhaseBadge extends StatelessWidget {
  const PhaseBadge(this.fase, {this.compact = false, this.onDark = false, super.key});

  final Fase fase;

  /// Versión pequeña para líneas de metadatos (tarjeta de publicación, chat).
  final bool compact;

  /// Sobre fondo rojo (cabecera del chat): pastilla blanca con el texto del color de la
  /// fase. Si no, «Activo» (rojo) desaparecería sobre la barra roja.
  final bool onDark;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Fase: ${fase.label}',
    excludeSemantics: true,
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 1 : 2),
      decoration: BoxDecoration(
        color: onDark ? Colors.white : IcexColors.phase(fase),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        fase.label,
        style: TextStyle(
          color: onDark
              ? (fase == Fase.fase1 ? IcexColors.onAccent : IcexColors.phase(fase))
              : IcexColors.onPhase(fase),
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    ),
  );
}

/// Etiqueta amarilla "49ª promoción".
class PromoBadge extends StatelessWidget {
  const PromoBadge(this.promocion, {this.compact = false, super.key});

  final int promocion;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 1),
    decoration: BoxDecoration(color: IcexColors.promoTag, borderRadius: BorderRadius.circular(6)),
    child: Text(
      compact ? '$promocionª promo' : '$promocionª promoción',
      semanticsLabel: '$promocionª promoción',
      style: TextStyle(
        color: IcexColors.onAccent,
        fontSize: compact ? 10 : 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

/// Badge del tipo de publicación (Evento, Oportunidad laboral, Logro, Comunicado).
class PostTypeBadge extends StatelessWidget {
  const PostTypeBadge(this.tipo, {super.key});

  final PostTipo tipo;

  static (IconData, String) describe(PostTipo t) => switch (t) {
    PostTipo.evento => (Icons.calendar_month_outlined, 'Evento'),
    PostTipo.oportunidadLaboral => (Icons.work_outline, 'Oportunidad laboral'),
    PostTipo.logro => (Icons.emoji_events_outlined, 'Logro'),
    PostTipo.novedadOficial => (Icons.push_pin_outlined, 'Comunicado de la asociación'),
    PostTipo.general => (Icons.article_outlined, 'Publicación'),
  };

  @override
  Widget build(BuildContext context) {
    final (icon, label) = describe(tipo);
    final official = tipo == PostTipo.novedadOficial;
    // Flexible + elipsis: en móviles pequeños o con texto grande la etiqueta se recorta en
    // lugar de desbordar la fila.
    final text = Flexible(
      child: Text(
        official ? label.toUpperCase() : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: IcexColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
    // Los comunicados oficiales van sin pastilla (ya están sobre un fondo tintado).
    if (official) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.push_pin_outlined, size: 14, color: IcexColors.primary),
          const SizedBox(width: 4),
          text,
        ],
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
      decoration: BoxDecoration(
        color: IcexColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: IcexColors.primary),
          const SizedBox(width: 5),
          text,
        ],
      ),
    );
  }
}

/// Fila con fase + promoción, usada en tarjetas y cabeceras.
class PhasePromoRow extends StatelessWidget {
  const PhasePromoRow({
    required this.fase,
    required this.promocion,
    this.compact = false,
    this.alignment = WrapAlignment.start,
    super.key,
  });

  final Fase fase;
  final int promocion;
  final bool compact;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    alignment: alignment,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      PhaseBadge(fase, compact: compact),
      PromoBadge(promocion, compact: compact),
    ],
  );
}

/// Contador de no leídos (rojo, como en la barra de navegación del mockup).
class CountBadge extends StatelessWidget {
  const CountBadge({required this.count, required this.child, this.onDark = false, super.key});

  final int count;
  final Widget child;

  /// Sobre la barra roja: amarillo ICEX con texto oscuro (el rojo no se distinguiría).
  final bool onDark;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    // La cifra ya la anuncia el tooltip/etiqueta del botón; se excluye para no leerla dos
    // veces (y para no mezclar su color con el del icono al medir contraste).
    label: ExcludeSemantics(child: Text(count > 99 ? '99+' : '$count')),
    backgroundColor: onDark ? IcexColors.accent : IcexColors.primary,
    textColor: onDark ? IcexColors.onAccent : Colors.white,
    child: child,
  );
}
