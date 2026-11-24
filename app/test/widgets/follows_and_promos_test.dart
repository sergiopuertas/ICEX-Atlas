import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/features/auth/presentation/login_page.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';

import '../helpers/app_harness.dart';

void main() {
  group('Seguidores / siguiendo', () {
    testWidgets('tocar «seguidores» del perfil abre la lista', (t) async {
      final api = fullDemoApi();
      await pumpApp(t, appHarness(api), location: '/perfil/javier');
      await t.tap(find.byKey(const Key('stat-seguidores')));
      await settleData(t);
      expect(find.text('Seguidor Número 0'), findsOneWidget);
      expect(api.last('list_follows').params['p_direction'], 'seguidores');
      expect(api.last('list_follows').params['p_user'], 'u-2');
    });

    testWidgets('tocar «siguiendo» abre directamente esa pestaña', (t) async {
      final api = fullDemoApi();
      await pumpApp(t, appHarness(api), location: '/perfil/javier');
      await t.tap(find.byKey(const Key('stat-siguiendo')));
      await settleData(t);
      expect(find.text('Seguida Número 0'), findsOneWidget);
      expect(api.last('list_follows').params['p_direction'], 'siguiendo');
    });

    testWidgets('seguir desde la lista llama a la API y cambia el botón', (t) async {
      final api = fullDemoApi();
      await pumpApp(t, appHarness(api), location: '/perfil/javier/conexiones');
      // Seguidor 1 (impar): aún no le sigo.
      final tile = find.ancestor(
        of: find.text('Seguidor Número 1'),
        matching: find.byType(ListTile),
      );
      await t.tap(find.descendant(of: tile, matching: find.text('Seguir')));
      await settleData(t);
      expect(api.last('follow').params['p_user'], 'u-sd1');
      expect(find.descendant(of: tile, matching: find.text('Siguiendo')), findsOneWidget);
    });

    testWidgets('abrir un perfil desde la lista', (t) async {
      final api = fullDemoApi();
      await pumpApp(t, appHarness(api), location: '/perfil/javier/conexiones');
      await t.tap(find.text('Seguidor Número 2'));
      await settleData(t);
      expect(api.calls.where((c) => c.name == 'get_profile').length, greaterThanOrEqualTo(2));
    });
  });

  group('Promociones', () {
    test('la promoción en curso sube cada año (2026 → 51ª)', () {
      expect(currentPromocion(now: DateTime(2026, 11, 24)), 51);
      expect(currentPromocion(now: DateTime(2027, 1, 2)), 52);
      expect(
        currentPromocion(now: DateTime(2027), fromServer: 51),
        51,
        reason: 'ajuste manual del servidor',
      );
    });

    test('CommunityStats lee la promoción en curso del servidor', () {
      final s = CommunityStats.fromJson({'alumni': 1, 'promocion_actual': 52});
      expect(s.promocionActual, 52);
      expect(CommunityStats.fromJson(const {}).promocionActual, isNull);
    });
  });

  group('Acceso de desarrollo: errores que dicen qué hacer', () {
    test('email desactivado / cuentas sin cargar / sin red', () {
      expect(
        devLoginErrorHelp(
          'AuthApiException(message: Email logins are disabled, code: email_provider_disabled)',
        ),
        contains('supabase stop'),
      );
      expect(devLoginErrorHelp('Invalid login credentials'), contains('setup-local'));
      expect(devLoginErrorHelp('SocketException: Connection refused'), contains('android-dev'));
      expect(devLoginErrorHelp('otra cosa'), contains('otra cosa'));
    });
  });
}
