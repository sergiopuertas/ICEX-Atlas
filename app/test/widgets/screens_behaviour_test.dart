import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/config/app_env.dart';
import 'package:icex_atlas/features/auth/domain/dev_accounts.dart';
import 'package:icex_atlas/features/auth/presentation/login_page.dart';
import 'package:icex_atlas/features/feed/presentation/home_page.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/expandable_text.dart';

import '../application/controllers_test.dart' show container;
import '../goldens/screens_golden_test.dart' show harness;
import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';

const _env = AppEnv(
  supabaseUrl: 'http://x',
  supabaseAnonKey: 'k',
  oidcProvider: 'custom:icex-alumni',
  authRedirect: 'x://y',
  environment: 'local',
);

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Inicio', () {
    testWidgets('sin anuncio del Orientador ni cifras entre publicaciones', (t) async {
      await pumpApp(t, appHarness(fullDemoApi(posts: 8)), size: const Size(390, 4000));
      expect(find.text('Orientador Alumni'), findsNothing);
      expect(find.text('La comunidad en cifras'), findsNothing);
      // Solo un bloque intercalado: las sugerencias de personas, una vez.
      expect(find.byType(SuggestionsCarousel), findsOneWidget);
    });

    testWidgets('«Leer más» despliega y «Mostrar menos» recoge un texto largo', (t) async {
      await pumpApp(t, appHarness(fullDemoApi()));
      final toggle = find.byKey(const Key('expandable-toggle')).first;
      expect(find.text('Leer más'), findsWidgets);
      await t.tap(toggle);
      await t.pump();
      expect(find.text('Mostrar menos'), findsOneWidget);
      await t.ensureVisible(find.text('Mostrar menos'));
      await t.pump();
      await t.tap(find.text('Mostrar menos'));
      await t.pump();
      expect(find.text('Mostrar menos'), findsNothing);
    });

    testWidgets('un texto corto no muestra «Leer más»', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          locale: Locale('es'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: ExpandableText('Texto breve')),
        ),
      );
      expect(find.byKey(const Key('expandable-toggle')), findsNothing);
    });

    testWidgets('el saludo usa el nombre de pila', (t) async {
      await pumpApp(t, appHarness(fullDemoApi()));
      expect(find.text('Hola, Ana'), findsOneWidget);
    });
  });

  group('Orientador', () {
    testWidgets('sin texto libre ni ideas prefabricadas; el contexto viene del perfil', (t) async {
      final api = fullDemoApi()
        ..responders['orientador'] = (_) => {
          'resumen': 'Resumen',
          'pasos': ['Paso uno'],
          'alumni': <Object>[],
          'aviso': 'Aviso',
        };
      await pumpApp(t, appHarness(api), location: '/orientador');
      expect(find.text('Ideas para empezar'), findsNothing);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.byType(TextField), findsNothing, reason: 'sin campo de texto');
      await t.tap(find.byKey(const Key('orientador-submit')));
      await settleData(t);
      final body = api.last('orientador').params['body'] as Map;
      expect(body['consulta'], '');
      expect(body['fase'], 'activo', reason: 'la fase de Ana');
      expect(find.text('Paso uno'), findsOneWidget);
    });
  });

  group('Acceso de desarrollo', () {
    test('DEV_LOGIN nunca se activa en producción', () {
      const prod = AppEnv(
        supabaseUrl: 'x',
        supabaseAnonKey: 'k',
        oidcProvider: 'p',
        authRedirect: 'r',
        environment: 'production',
        devLoginRequested: true,
      );
      expect(prod.devLogin, isFalse);
      const local = AppEnv(
        supabaseUrl: 'x',
        supabaseAnonKey: 'k',
        oidcProvider: 'p',
        authRedirect: 'r',
        environment: 'local',
        devLoginRequested: true,
      );
      expect(local.devLogin, isTrue);
    });

    testWidgets('sin DEV_LOGIN no aparece el panel', (t) async {
      await t.pumpWidget(harness(const LoginPage(), FakeApiClient(), auth: FakeAuthGateway()));
      await settleData(t);
      expect(find.byKey(const Key('dev-login')), findsNothing);
    });

    testWidgets('con DEV_LOGIN, un toque entra con email y contraseña (sin navegador)', (t) async {
      final auth = FakeAuthGateway();
      await t.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        harness(
          const LoginPage(),
          FakeApiClient(),
          auth: auth,
          env: const AppEnv(
            supabaseUrl: 'http://x',
            supabaseAnonKey: 'k',
            oidcProvider: 'custom:icex-alumni',
            authRedirect: 'x://y',
            environment: 'local',
            devLoginRequested: true,
          ),
        ),
      );
      await settleData(t);
      expect(find.byKey(const Key('dev-login')), findsOneWidget);
      await t.tap(find.text(DevAccount.all.first.name));
      await t.pump();
      expect(auth.lastPasswordEmail, DevAccount.all.first.email);
      expect(auth.signInCalls, 0, reason: 'no abre el flujo OIDC');
    });

    test('una cuenta sin membresía termina en «Acceso solo para socios»', () async {
      final auth = FakeAuthGateway()
        ..onPasswordSignIn = (_) async => throw Exception('icex_member_not_active');
      final c = container(FakeApiClient(), auth: auth)..read(sessionControllerProvider);
      await c
          .read(sessionControllerProvider.notifier)
          .signInWithPassword(email: 'pedro@x', password: DevAccount.password);
      expect(c.read(sessionControllerProvider), isA<AccessDenied>());
      expect(_env.devLogin, isFalse, reason: 'sin DEV_LOGIN por defecto');
    });
  });
}
