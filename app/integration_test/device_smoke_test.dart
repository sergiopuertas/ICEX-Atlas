import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/features/feed/presentation/home_page.dart';
import 'package:icex_atlas/main.dart' as app;
import 'package:integration_test/integration_test.dart';

/// Prueba de humo en MÓVILES REALES (Firebase Test Lab, `.github/workflows/device-test.yml`).
///
/// A diferencia de los widget tests, aquí corre la app de verdad: el arranque nativo, el
/// almacenamiento seguro, la red real (TLS), Supabase y el render en cada modelo de móvil.
/// Va contra el backend de la beta (staging) con una cuenta de prueba que el flujo crea y
/// borra (`scripts/deploy/test_account.py`), y que llega como --dart-define:
///   TEST_EMAIL / TEST_PASSWORD
/// Sin cuenta, solo comprueba la parte sin sesión (portada y formulario de registro).
const _email = String.fromEnvironment('TEST_EMAIL');
const _password = String.fromEnvironment('TEST_PASSWORD');

Future<void> pumpUntil(
  WidgetTester t,
  Finder f, {
  Duration timeout = const Duration(seconds: 40),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await t.pump(const Duration(milliseconds: 250));
    if (f.evaluate().isNotEmpty) return;
  }
  throw TestFailure('No apareció a tiempo: $f');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('arranca, deja registrarse y, con cuenta, entra y recorre las pestañas', (t) async {
    await app.main();

    // Sin sesión: portada de la beta y formulario de alta.
    await pumpUntil(t, find.byKey(const Key('beta-signup')));
    await t.tap(find.byKey(const Key('beta-signup')));
    await pumpUntil(t, find.byKey(const Key('auth-name')));
    expect(find.byKey(const Key('auth-email')), findsOneWidget);
    expect(find.byKey(const Key('auth-password')), findsOneWidget);
    await t.pageBack();
    await pumpUntil(t, find.byKey(const Key('beta-signin')));

    if (_email.isEmpty) {
      markTestSkipped('Sin TEST_EMAIL: solo se probó la parte sin sesión.');
      return;
    }

    // Entrar con la cuenta de prueba y ver el feed real.
    await t.tap(find.byKey(const Key('beta-signin')));
    await pumpUntil(t, find.byKey(const Key('auth-email')));
    await t.enterText(find.byKey(const Key('auth-email')), _email);
    await t.enterText(find.byKey(const Key('auth-password')), _password);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.tap(find.byKey(const Key('auth-submit')));
    await pumpUntil(t, find.byType(HomePage));
    await pumpUntil(t, find.byType(NavigationBar));

    // Cada pestaña principal pinta sin errores.
    for (final tab in ['Red', 'Mapa', 'Mensajes', 'Inicio']) {
      await t.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 250));
      }
      expect(t.takeException(), isNull, reason: 'pestaña $tab');
    }
  });
}
