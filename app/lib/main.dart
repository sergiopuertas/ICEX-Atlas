import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/app.dart';
import 'package:icex_atlas/core/auth/secure_storage.dart';
import 'package:icex_atlas/core/config/app_env.dart';
import 'package:icex_atlas/core/errors/error_reporter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = AppEnv.fromEnvironment();
  // En paralelo: menos tiempo con la pantalla en blanco al abrir la app.
  final dates = initializeDateFormatting('es');

  await Supabase.initialize(
    url: env.supabaseUrl,
    publishableKey: env.supabaseAnonKey,
    authOptions: FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(),
      pkceAsyncStorage: SecurePkceStorage(),
    ),
    postgrestOptions: const PostgrestClientOptions(schema: 'api'),
  );
  await dates;

  // Firebase solo si hay configuración (google-services.json / GoogleService-Info.plist).
  try {
    await Firebase.initializeApp();
  } on Object {
    // Sin Firebase en local: las notificaciones push quedan desactivadas.
  }

  const app = ProviderScope(child: AtlasApp());
  if (!env.hasSentry) {
    runApp(app);
    return;
  }
  await SentryFlutter.init((o) {
    o
      ..dsn = env.sentryDsn
      ..environment = env.environment
      ..sendDefaultPii = false
      ..tracesSampleRate = env.isProduction ? 0.1 : 0
      ..beforeSend = scrubEvent;
  }, appRunner: () => runApp(app));
}
