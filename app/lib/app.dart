import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/presence/presence.dart';
import 'package:icex_atlas/core/push/push_service.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';

class AtlasApp extends ConsumerWidget {
  const AtlasApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Servicios ligados a la sesión (heartbeat de presencia, push y reintento del outbox).
    ref
      ..watch(presenceProvider)
      ..watch(pushServiceProvider);
    return MaterialApp.router(
      title: 'ICEX Alumni',
      debugShowCheckedModeBanner: false,
      theme: IcexTheme.light(),
      routerConfig: ref.watch(appRouterProvider),
      locale: const Locale('es'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
