import 'package:flutter/material.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';

/// Badge redondeado de fase: Fase 0 · Fase I · Fase II · ACTIVO.
class PhaseBadge extends StatelessWidget {
  const PhaseBadge(this.fase, {super.key});

  final Fase fase;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Fase: ${fase.label}',
    excludeSemantics: true,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: IcexColors.phase(fase),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        fase.label,
        style: TextStyle(
          color: IcexColors.onPhase(fase),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    ),
  );
}

/// Etiqueta amarilla "49ª promoción".
class PromoBadge extends StatelessWidget {
  const PromoBadge(this.promocion, {super.key});

  final int promocion;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(color: IcexColors.promoTag, borderRadius: BorderRadius.circular(6)),
    child: Text(
      '$promocionª promoción',
      style: const TextStyle(color: IcexColors.onAccent, fontSize: 11, fontWeight: FontWeight.w600),
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: IcexColors.primary),
        const SizedBox(width: 6),
        Text(
          tipo == PostTipo.novedadOficial ? label.toUpperCase() : label,
          style: const TextStyle(
            color: IcexColors.primary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Fila con fase + promoción, usada en tarjetas y cabeceras.
class PhasePromoRow extends StatelessWidget {
  const PhasePromoRow({required this.fase, required this.promocion, super.key});

  final Fase fase;
  final int promocion;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [PhaseBadge(fase), PromoBadge(promocion)],
  );
}

/// Contador de no leídos (rojo, como en la barra de navegación del mockup).
class CountBadge extends StatelessWidget {
  const CountBadge({required this.count, required this.child, super.key});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: count > 0,
    label: Text(count > 99 ? '99+' : '$count'),
    backgroundColor: IcexColors.primary,
    child: child,
  );
}
