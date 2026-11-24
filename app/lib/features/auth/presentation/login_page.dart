import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:icex_atlas/shared/widgets/links.dart';

/// Portada a pantalla completa (como las de LinkedIn o Instagram): arriba, una cabecera
/// roja ICEX con un globo de puntos y conexiones, el mensaje y tres ventajas; abajo, una
/// hoja blanca con la acción principal. Ocupa todo el alto en cualquier móvil y, si no
/// cabe (pantallas pequeñas o texto grande), se desplaza.
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final AppLifecycleListener _lifecycle;
  Timer? _abandonTimer;

  @override
  void initState() {
    super.initState();
    // El acceso se completa en el navegador. Si el usuario vuelve a la app sin terminarlo
    // (atrás, cerrar la pestaña), no llega ninguna respuesta: tras unos segundos se
    // reactiva el botón. Si la respuesta llega (deep link), el estado ya habrá cambiado.
    _lifecycle = AppLifecycleListener(
      onResume: () {
        _abandonTimer?.cancel();
        _abandonTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) ref.read(sessionControllerProvider.notifier).signInAbandoned();
        });
      },
    );
  }

  @override
  void dispose() {
    _abandonTimer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final session = ref.watch(sessionControllerProvider);
    final busy = session is SigningIn;
    final error = session is SignedOut ? session.error : null;
    final env = ref.watch(appEnvProvider);

    return _WelcomeScaffold(
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AccentBar(),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: Text(
              l.loginTitle,
              style: t.headlineLarge?.copyWith(color: Colors.white, fontSize: 34, height: 1.1),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.loginSubtitle,
            style: t.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 28),
          _Feature(icon: Icons.public_rounded, text: l.loginFeatureWorld),
          _Feature(icon: Icons.groups_rounded, text: l.loginFeaturePromo),
          _Feature(icon: Icons.work_outline_rounded, text: l.loginFeatureOpportunities),
        ],
      ),
      sheet: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            key: const Key('login-button'),
            onPressed: busy
                ? null
                : () {
                    unawaited(HapticFeedback.selectionClick());
                    unawaited(ref.read(sessionControllerProvider.notifier).signIn());
                  },
            icon: busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.login),
            label: Text(busy ? l.loginInProgress : l.loginButton, textAlign: TextAlign.center),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              disabledBackgroundColor: IcexColors.primary.withValues(alpha: 0.75),
              disabledForegroundColor: Colors.white,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                error == 'network' ? l.errorNetwork : l.loginError,
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: IcexColors.destructive),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => openExternalUrl(context, env.membershipUrl),
            child: Text.rich(
              TextSpan(
                text: '${l.loginNotMember} ',
                style: const TextStyle(
                  color: IcexColors.mutedForeground,
                  fontWeight: FontWeight.w400,
                ),
                children: [
                  TextSpan(
                    text: l.loginJoin,
                    style: const TextStyle(color: IcexColors.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),
          Text(l.loginPrivacyNote, textAlign: TextAlign.center, style: t.bodySmall),
        ],
      ),
    );
  }
}

/// Pantalla para quien no es socio verificado: no muestra ningún contenido de la red.
class AccessDeniedPage extends ConsumerWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final env = ref.watch(appEnvProvider);
    final session = ref.read(sessionControllerProvider.notifier);
    return _WelcomeScaffold(
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline_rounded, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 20),
          Semantics(
            header: true,
            child: Text(
              l.accessDeniedTitle,
              style: t.headlineLarge?.copyWith(color: Colors.white, fontSize: 30, height: 1.15),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.accessDeniedBody,
            style: t.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
      sheet: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => openExternalUrl(context, env.membershipUrl),
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            label: Text(l.accessDeniedWeb),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('switch-account'),
            onPressed: () => session.signIn(switchAccount: true),
            icon: const Icon(Icons.switch_account_outlined, size: 20),
            label: Text(l.accessDeniedOtherAccount),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 4),
          TextButton(onPressed: session.reset, child: Text(l.accessDeniedRetry)),
        ],
      ),
    );
  }
}

/// Estructura común: cabecera roja que se estira para llenar la pantalla + hoja blanca.
class _WelcomeScaffold extends StatelessWidget {
  const _WelcomeScaffold({required this.hero, required this.sheet});

  final Widget hero;
  final Widget sheet;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Iconos de la barra de estado en blanco sobre el rojo.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: IcexColors.card,
        body: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFD10A1C), IcexColors.primary, Color(0xFF7E0310)],
                            stops: [0, 0.45, 1],
                          ),
                        ),
                        child: Stack(
                          children: [
                            const Positioned.fill(
                              child: ExcludeSemantics(child: CustomPaint(painter: _GlobePainter())),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(28, padding.top + 20, 28, 48),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _LogoBadge(),
                                  const Spacer(),
                                  const SizedBox(height: 32),
                                  hero,
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // La hoja se superpone un poco a la cabecera (esquinas redondeadas).
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: IcexColors.card,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        padding: EdgeInsets.fromLTRB(24, 28, 24, 8 + padding.bottom),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: sheet,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 16, offset: Offset(0, 6))],
    ),
    child: const IcexLogo(),
  );
}

class _AccentBar extends StatelessWidget {
  const _AccentBar();

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 5,
    decoration: BoxDecoration(color: IcexColors.accent, borderRadius: BorderRadius.circular(4)),
  );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: IcexColors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyLarge
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

/// Globo de puntos con arcos de conexión (dibujo propio, decorativo): la red repartida por
/// el mundo. Se dibuja en la esquina superior derecha, parcialmente fuera de la pantalla.
class _GlobePainter extends CustomPainter {
  const _GlobePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.max<double>(size.width * 0.62, 220);
    final center = Offset(size.width * 0.92, size.height * 0.30);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.12);

    // Contorno, meridianos y paralelos.
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

    // Puntos (alumni) sobre la esfera, deterministas.
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.35);
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

    // Arcos de conexión entre algunos puntos, con el destino en amarillo ICEX.
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = IcexColors.accent.withValues(alpha: 0.6);
    final hub = Paint()..color = IcexColors.accent;
    // Solo entre puntos relativamente cercanos y visibles: arcos cortos, como rutas.
    var drawn = 0;
    for (var i = 0; i < points.length && drawn < 7; i++) {
      final a = points[i];
      if (a.dx < 0 || a.dy < 0) continue;
      for (var j = i + 1; j < points.length; j++) {
        final b = points[j];
        final d = (b - a).distance;
        if (b.dx < 0 || b.dy < 0 || d < r * 0.25 || d > r * 0.55) continue;
        final mid = Offset.lerp(a, b, 0.5)!;
        // Curva hacia «arriba» del tramo (normal con componente y negativa).
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
        i += 4; // reparte los arcos por el globo
        break;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) => false;
}
