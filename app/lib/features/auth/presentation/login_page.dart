import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final session = ref.watch(sessionControllerProvider);
    final busy = session is SigningIn;
    final error = session is SignedOut ? session.error : null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const IcexStripe(height: 6),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: IcexCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: IcexLogo(height: 36)),
                          const SizedBox(height: 28),
                          Semantics(
                            header: true,
                            child: Text(
                              l.loginTitle,
                              style: t.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l.loginSubtitle,
                            textAlign: TextAlign.center,
                            style: t.bodyLarge?.copyWith(color: IcexColors.mutedForeground),
                          ),
                          const SizedBox(height: 28),
                          FilledButton.icon(
                            key: const Key('login-button'),
                            onPressed: busy
                                ? null
                                : () => ref.read(sessionControllerProvider.notifier).signIn(),
                            icon: busy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(busy ? l.loginInProgress : l.loginButton),
                            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              error == 'network' ? l.errorNetwork : l.loginError,
                              textAlign: TextAlign.center,
                              style: t.bodyMedium?.copyWith(color: IcexColors.destructive),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Text(l.loginPrivacyNote, textAlign: TextAlign.center, style: t.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
    final web = ref.watch(appEnvProvider).associationWebUrl;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const IcexStripe(height: 6),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline, size: 56, color: IcexColors.primary),
                        const SizedBox(height: 16),
                        Semantics(
                          header: true,
                          child: Text(
                            l.accessDeniedTitle,
                            style: t.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(l.accessDeniedBody, style: t.bodyLarge, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: () =>
                              launchUrl(Uri.parse(web), mode: LaunchMode.externalApplication),
                          child: Text(l.accessDeniedWeb),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => ref.read(sessionControllerProvider.notifier).reset(),
                          child: Text(l.accessDeniedRetry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
