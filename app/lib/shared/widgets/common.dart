import 'package:flutter/material.dart';
import 'package:icex_atlas/core/errors/failure.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

/// Franja superior roja/amarilla/roja del mockup.
class IcexStripe extends StatelessWidget {
  const IcexStripe({super.key, this.height = 4});

  final double height;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ColoredBox(color: IcexColors.primary)),
          Expanded(flex: 2, child: ColoredBox(color: IcexColors.accent)),
          Expanded(child: ColoredBox(color: IcexColors.primary)),
        ],
      ),
    ),
  );
}

/// Logotipo ICEX Alumni.
class IcexLogo extends StatelessWidget {
  const IcexLogo({super.key, this.height = 26});

  final double height;

  /// Proporción del archivo del logotipo (425 × 88; sin el sello del 50 aniversario): con ancho fijo el hueco no cambia de
  /// tamaño mientras la imagen se carga.
  static const double _aspect = 425 / 88;

  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/images/icex_alumni_logo.png',
    height: height,
    width: height * _aspect,
    semanticLabel: 'ICEX Alumni',
    errorBuilder: (_, _, _) => Text(
      'icex_alumni',
      style: TextStyle(
        color: IcexColors.primary,
        fontWeight: FontWeight.w700,
        fontSize: height * 0.8,
      ),
    ),
  );
}

/// Aviso de comunidad de demostración (datos ficticios).
class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    padding: const EdgeInsets.only(left: 12),
    decoration: const BoxDecoration(
      border: Border(left: BorderSide(color: IcexColors.primary, width: 2)),
    ),
    child: Text(
      AppLocalizations.of(context).demoBanner,
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: IcexColors.mutedForeground),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    ),
  );
}

/// Estado de error con mensaje según el tipo de fallo y botón de reintento.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, this.onRetry, super.key});

  final Object error;
  final VoidCallback? onRetry;

  static String messageFor(AppLocalizations l, Object error) => switch (error) {
    NetworkFailure() => l.errorNetwork,
    ForbiddenFailure() => l.errorForbidden,
    NotFoundFailure() => l.errorNotFound,
    RateLimitedFailure(:final message) => message,
    ValidationFailure(:final message) when message.isNotEmpty => message,
    _ => l.errorGeneric,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return EmptyState(
      icon: error is NetworkFailure ? Icons.cloud_off_outlined : Icons.error_outline,
      message: messageFor(l, error),
      action: onRetry == null ? null : OutlinedButton(onPressed: onRetry, child: Text(l.retry)),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      label: AppLocalizations.of(context).loading,
      child: const CircularProgressIndicator(color: IcexColors.primary),
    ),
  );
}

/// Tarjeta blanca con borde suave del mockup. Material (no DecoratedBox) para que las
/// salpicaduras de ListTile/InkWell sean visibles; acento rojo opcional a la izquierda.
class IcexCard extends StatelessWidget {
  const IcexCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentLeft = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool accentLeft;

  @override
  Widget build(BuildContext context) => Material(
    color: IcexColors.card,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(IcexTheme.radius),
      side: const BorderSide(color: IcexColors.border),
    ),
    child: accentLeft
        ? Stack(
            children: [
              Padding(padding: padding.add(const EdgeInsets.only(left: 4)), child: child),
              const Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: ColoredBox(color: IcexColors.primary),
              ),
            ],
          )
        : Padding(padding: padding, child: child),
  );
}

void showSnack(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// 6340 → «6,3 mil»; 1250000 → «1,3 M» (formato corto en español).
String compactNumber(int n) => n < 10000
    ? NumberFormat.decimalPattern('es').format(n)
    : NumberFormat.compact(locale: 'es').format(n);

/// Esqueleto de publicación mientras carga el feed (en lugar de un spinner en blanco):
/// la pantalla «tiene forma» desde el primer frame, como en LinkedIn o Instagram.
class PostSkeleton extends StatefulWidget {
  const PostSkeleton({super.key});

  @override
  State<PostSkeleton> createState() => _PostSkeletonState();
}

class _PostSkeletonState extends State<PostSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, {double h = 12}) => Container(
      width: w,
      height: h,
      decoration: BoxDecoration(color: IcexColors.muted, borderRadius: BorderRadius.circular(6)),
    );
    return Semantics(
      label: AppLocalizations.of(context).loading,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_c),
        child: Container(
          color: IcexColors.card,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: IcexColors.muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [bar(140), const SizedBox(height: 8), bar(90, h: 10)],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              bar(double.infinity),
              const SizedBox(height: 8),
              bar(double.infinity),
              const SizedBox(height: 8),
              bar(200),
              const SizedBox(height: 16),
              bar(double.infinity, h: 160),
            ],
          ),
        ),
      ),
    );
  }
}
