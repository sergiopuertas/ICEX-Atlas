import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/auth/domain/dev_accounts.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/brand.dart';
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
          const AccentBar(),
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
                error == 'network'
                    ? l.errorNetwork
                    : env.devLogin
                    ? devLoginErrorHelp(error)
                    : l.loginError,
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
          if (env.devLogin) ...[const SizedBox(height: 20), _DevLoginPanel(enabled: !busy)],
        ],
      ),
    );
  }
}

/// Acceso rápido de desarrollo: entrar como una cuenta de prueba con un toque, sin pasar
/// por el navegador ni el proveedor OIDC. Solo aparece con DEV_LOGIN=true y nunca en
/// producción (ver `AppEnv.devLogin` y docs/autenticacion.md).
class _DevLoginPanel extends ConsumerWidget {
  const _DevLoginPanel({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      key: const Key('dev-login'),
      color: IcexColors.muted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: IcexColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.code_rounded, size: 18, color: IcexColors.mutedForeground),
                const SizedBox(width: 6),
                Expanded(child: Text(l.devLoginTitle, style: t.titleSmall)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(l.devLoginHint, style: t.bodySmall),
            ),
            for (final a in DevAccount.all)
              ListTile(
                dense: true,
                enabled: enabled,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: IcexColors.card,
                  child: Text(
                    a.name.split(' ').take(2).map((w) => w[0]).join(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: IcexColors.primary,
                    ),
                  ),
                ),
                title: Text(a.name, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text(a.role, style: t.bodySmall),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => ref
                    .read(sessionControllerProvider.notifier)
                    .signInWithPassword(email: a.email, password: DevAccount.password),
              ),
          ],
        ),
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
                              child: ExcludeSemantics(child: CustomPaint(painter: GlobePainter())),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(28, padding.top + 20, 28, 48),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const LogoBadge(),
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

/// Solo en desarrollo (DEV_LOGIN): el motivo real y cómo arreglarlo, en vez de un error
/// genérico. Nunca se muestra en producción.
@visibleForTesting
String devLoginErrorHelp(String error) {
  final e = error.toLowerCase();
  if (e.contains('email_provider_disabled') || e.contains('logins are disabled')) {
    return 'El acceso con email está desactivado en tu Supabase local. '
        'Reinícialo: supabase stop && ./scripts/start-local.sh';
  }
  if (e.contains('invalid login') || e.contains('invalid_credentials')) {
    return 'Las cuentas de prueba no están en tu base local. Ejecuta ./scripts/setup-local.sh';
  }
  if (e.contains('socket') || e.contains('connection') || e.contains('failed host lookup')) {
    return 'La app no llega a Supabase (127.0.0.1:54321). En el emulador: ./scripts/android-dev.sh';
  }
  return 'No se pudo entrar: $error';
}
