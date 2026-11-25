import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/core/auth/auth_errors.dart';
import 'package:icex_atlas/core/auth/auth_gateway.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthApiException;

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';

void main() {
  FakeAuthGateway signedOut() => FakeAuthGateway();

  group('Beta abierta: portada', () {
    testWidgets('muestra «Crear cuenta» y «Ya tengo cuenta», no el botón de ICEX Alumni', (
      t,
    ) async {
      await pumpApp(t, appHarness(fullDemoApi(), auth: signedOut(), env: betaEnv));
      expect(find.byKey(const Key('beta-signup')), findsOneWidget);
      expect(find.byKey(const Key('beta-signin')), findsOneWidget);
      expect(find.byKey(const Key('login-button')), findsNothing);
      expect(find.text('BETA'), findsOneWidget);
    });

    testWidgets('sin AUTH_MODE=password sigue el acceso de socios', (t) async {
      await pumpApp(t, appHarness(fullDemoApi(), auth: signedOut()));
      expect(find.byKey(const Key('login-button')), findsOneWidget);
      expect(find.byKey(const Key('beta-signup')), findsNothing);
    });
  });

  group('Beta abierta: crear cuenta', () {
    Future<FakeAuthGateway> openSignUp(WidgetTester t) async {
      final auth = signedOut();
      await pumpApp(t, appHarness(fullDemoApi(), auth: auth, env: betaEnv));
      await t.tap(find.byKey(const Key('beta-signup')));
      await settleData(t);
      return auth;
    }

    testWidgets('valida nombre, email, contraseña y privacidad antes de enviar', (t) async {
      final auth = await openSignUp(t);
      await t.tap(find.byKey(const Key('auth-submit')));
      await settleData(t);
      expect(find.text('Escribe tu nombre (mínimo 2 letras)'), findsOneWidget);
      expect(find.text('Escribe un correo válido'), findsOneWidget);
      expect(find.text('La contraseña debe tener al menos 8 caracteres'), findsOneWidget);
      expect(find.text('Tienes que aceptar la política de privacidad'), findsOneWidget);
      expect(auth.lastSignUp, isNull);
    });

    testWidgets('alta correcta → «Revisa tu correo»; reenviar y volver', (t) async {
      final auth = await openSignUp(t);
      await t.enterText(find.byKey(const Key('auth-name')), 'Lucía Pérez');
      await t.enterText(find.byKey(const Key('auth-email')), ' lucia@example.com ');
      await t.enterText(find.byKey(const Key('auth-password')), 'contraseña-segura');
      await t.ensureVisible(find.byKey(const Key('auth-accept')));
      await t.tap(find.byKey(const Key('auth-accept')));
      await t.ensureVisible(find.byKey(const Key('auth-submit')));
      await t.tap(find.byKey(const Key('auth-submit')));
      await settleData(t);
      expect(auth.lastSignUp, {
        'email': 'lucia@example.com',
        'password': 'contraseña-segura',
        'name': 'Lucía Pérez',
        'promocion': null,
      });
      expect(find.byKey(const Key('check-email-body')), findsOneWidget);
      expect(find.textContaining('lucia@example.com'), findsOneWidget);
      await t.tap(find.byKey(const Key('resend')));
      await settleData(t);
      expect(auth.resends, ['lucia@example.com']);
      expect(find.text('Correo reenviado.'), findsOneWidget);
    });

    testWidgets('correo ya registrado → mensaje claro', (t) async {
      final auth = await openSignUp(t)
        ..onSignUp = (_) =>
            throw const AuthApiException('User already registered', code: 'user_already_exists');
      await t.enterText(find.byKey(const Key('auth-name')), 'Lucía Pérez');
      await t.enterText(find.byKey(const Key('auth-email')), 'lucia@example.com');
      await t.enterText(find.byKey(const Key('auth-password')), 'contraseña-segura');
      await t.ensureVisible(find.byKey(const Key('auth-accept')));
      await t.tap(find.byKey(const Key('auth-accept')));
      await t.ensureVisible(find.byKey(const Key('auth-submit')));
      await t.tap(find.byKey(const Key('auth-submit')));
      await settleData(t);
      expect(auth.lastSignUp, isNotNull);
      expect(find.textContaining('Ya hay una cuenta con este correo'), findsOneWidget);
    });
  });

  group('Beta abierta: entrar y recuperar', () {
    testWidgets('credenciales incorrectas → mensaje; correctas → entra', (t) async {
      final auth = signedOut()
        ..onPasswordSignIn = (_) =>
            throw const AuthApiException('Invalid login credentials', code: 'invalid_credentials');
      await pumpApp(t, appHarness(fullDemoApi(), auth: auth, env: betaEnv));
      await t.tap(find.byKey(const Key('beta-signin')));
      await settleData(t);
      await t.enterText(find.byKey(const Key('auth-email')), 'ana@example.com');
      await t.enterText(find.byKey(const Key('auth-password')), 'mala');
      await t.tap(find.byKey(const Key('auth-submit')));
      await settleData(t);
      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);

      auth.onPasswordSignIn = (_) async {
        auth
          ..currentUserId = 'u-1'
          ..emit(const AuthSignedIn('u-1'));
      };
      await t.enterText(find.byKey(const Key('auth-password')), 'buena-contraseña');
      await t.tap(find.byKey(const Key('auth-submit')));
      await settleData(t);
      expect(find.byKey(const Key('auth-submit')), findsNothing, reason: 'ya dentro de la app');
    });

    testWidgets('correo sin confirmar → pantalla «Revisa tu correo»', (t) async {
      final auth = signedOut()
        ..onPasswordSignIn = (_) =>
            throw const AuthApiException('Email not confirmed', code: 'email_not_confirmed');
      await pumpApp(t, appHarness(fullDemoApi(), auth: auth, env: betaEnv));
      await t.tap(find.byKey(const Key('beta-signin')));
      await settleData(t);
      await t.enterText(find.byKey(const Key('auth-email')), 'nueva@example.com');
      await t.enterText(find.byKey(const Key('auth-password')), 'contraseña-segura');
      await t.tap(find.byKey(const Key('auth-submit')));
      await settleData(t);
      expect(find.byKey(const Key('check-email-body')), findsOneWidget);
    });

    testWidgets('«He olvidado mi contraseña» envía el enlace', (t) async {
      final auth = signedOut();
      await pumpApp(t, appHarness(fullDemoApi(), auth: auth, env: betaEnv));
      await t.tap(find.byKey(const Key('beta-signin')));
      await settleData(t);
      await t.enterText(find.byKey(const Key('auth-email')), 'ana@example.com');
      await t.tap(find.byKey(const Key('auth-forgot')));
      await settleData(t);
      await t.tap(find.byKey(const Key('auth-submit')));
      await settleData(t);
      expect(auth.passwordResets, ['ana@example.com']);
      expect(find.byKey(const Key('auth-sent')), findsOneWidget);
    });

    testWidgets('enlace de recuperación → contraseña nueva → entra', (t) async {
      final auth = signedOut();
      await pumpApp(t, appHarness(fullDemoApi(), auth: auth, env: betaEnv));
      auth
        ..currentUserId = 'u-1'
        ..emit(const AuthPasswordRecovery('u-1'))
        ..emit(const AuthSignedIn('u-1')); // llega también: no debe saltarse la pantalla
      await settleData(t);
      expect(find.text('Elige una contraseña nueva'), findsOneWidget);
      await t.enterText(find.byKey(const Key('auth-password')), 'nueva-contraseña');
      await t.enterText(find.byKey(const Key('auth-password-repeat')), 'otra-distinta');
      await t.tap(find.byKey(const Key('auth-submit')));
      await settleData(t);
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      await t.enterText(find.byKey(const Key('auth-password-repeat')), 'nueva-contraseña');
      await t.tap(find.byKey(const Key('auth-submit')));
      await settleData(t);
      expect(auth.lastNewPassword, 'nueva-contraseña');
      expect(find.text('Elige una contraseña nueva'), findsNothing);
    });
  });

  group('Rutas y errores', () {
    test('sin sesión solo se ve la portada y los formularios de acceso', () {
      for (final p in ['/entrar', '/registro', '/recuperar', '/login']) {
        expect(redirectFor(const SignedOut(), Uri.parse(p)), isNull, reason: p);
      }
      expect(redirectFor(const SignedOut(), Uri.parse('/red')), Routes.login);
      expect(redirectFor(const AwaitingConfirmation('a@b.c'), Uri.parse('/')), Routes.checkEmail);
      expect(redirectFor(const PasswordRecovery('u'), Uri.parse('/')), Routes.newPassword);
    });

    test('códigos de error de Supabase Auth', () {
      expect(
        authErrorCode(const AuthApiException('x', code: 'invalid_credentials')),
        AuthErrorCode.invalidCredentials,
      );
      expect(
        authErrorCode(const AuthApiException('x', code: 'over_email_send_rate_limit')),
        AuthErrorCode.rateLimit,
      );
      expect(
        authErrorCode(const AuthApiException('x', code: 'weak_password')),
        AuthErrorCode.weakPassword,
      );
      expect(
        authErrorCode(const AuthApiException('Database error: signup_closed')),
        AuthErrorCode.signupClosed,
      );
      expect(
        authErrorCode(const AuthApiException('icex_member_not_active')),
        AuthErrorCode.notMember,
      );
    });
  });

  group('Cuenta beta dentro de la app', () {
    testWidgets('ajustes: comentarios de la beta y política de privacidad', (t) async {
      await pumpApp(t, appHarness(fullDemoApi(), env: betaEnv), location: '/ajustes');
      expect(find.byKey(const Key('feedback')), findsOneWidget);
      expect(find.text('Política de privacidad'), findsOneWidget);
    });

    testWidgets('una cuenta beta puede indicar su promoción al editar el perfil', (t) async {
      final api = fullDemoApi();
      final base = api.responders['me']!;
      api.responders['me'] = (p) => {...(base(p)! as Map<String, dynamic>), 'origen': 'beta'};
      await pumpApp(t, appHarness(api, env: betaEnv), location: '/perfil/editar');
      expect(find.byKey(const Key('edit-promo')), findsOneWidget);
    });

    testWidgets('un socio no ve ese campo (la promoción viene de ICEX Alumni)', (t) async {
      await pumpApp(t, appHarness(fullDemoApi()), location: '/perfil/editar');
      expect(find.byKey(const Key('edit-promo')), findsNothing);
    });
  });
}
