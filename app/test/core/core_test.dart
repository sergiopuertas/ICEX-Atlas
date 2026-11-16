import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/core/auth/auth_gateway.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/config/app_env.dart';
import 'package:icex_atlas/core/errors/error_reporter.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/core/utils/time_ago.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/l10n/app_localizations_es.dart';

import '../helpers/fakes.dart';

/// Contraste WCAG 2.x (luminancia relativa).
double contrast(Color a, Color b) {
  double lin(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) => 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
  final l1 = lum(a);
  final l2 = lum(b);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

void main() {
  final l = AppLocalizationsEs();

  group('redirectFor (router)', () {
    final me = Me.fromJson(meJson());
    Uri u(String s) => Uri.parse(s);

    test('sin sesión todo lleva a /login', () {
      expect(redirectFor(const SignedOut(), u('/')), Routes.login);
      expect(redirectFor(const SignedOut(), u('/perfil/x')), Routes.login);
      expect(redirectFor(const SignedOut(), u('/login')), isNull);
      expect(redirectFor(const SigningIn(), u('/mapa')), Routes.login);
    });

    test('no socio: solo la pantalla de acceso denegado', () {
      expect(redirectFor(const AccessDenied(), u('/')), Routes.accessDenied);
      expect(redirectFor(const AccessDenied(), u('/acceso-denegado')), isNull);
    });

    test('cargando sesión', () {
      expect(redirectFor(const SessionUnknown(), u('/')), Routes.splash);
      expect(redirectFor(const SessionUnknown(), u('/cargando')), isNull);
    });

    test('con sesión: fuera de login y deep link mensajes?to=', () {
      expect(redirectFor(SignedIn(me), u('/login')), Routes.home);
      expect(redirectFor(SignedIn(me), u('/cargando')), Routes.home);
      expect(redirectFor(SignedIn(me), u('/red')), isNull);
      expect(redirectFor(SignedIn(me), u('/mensajes?to=javier-1')), '/mensajes/nuevo?to=javier-1');
      expect(redirectFor(SignedIn(me), u('/mensajes')), isNull);
    });

    test('rutas con nombre', () {
      expect(Routes.profile('ana'), '/perfil/ana');
      expect(Routes.chat('c1'), '/mensajes/c1');
      expect(Routes.post('p1'), '/post/p1');
      expect(Routes.club('k1'), '/clubs/k1');
    });
  });

  test('timeAgo en español como el mockup', () {
    final now = DateTime(2026, 11, 16, 14);
    expect(timeAgo(l, now.subtract(const Duration(seconds: 20)), now: now), 'ahora');
    expect(timeAgo(l, now.subtract(const Duration(minutes: 15)), now: now), 'hace 15 min');
    expect(timeAgo(l, now.subtract(const Duration(hours: 3)), now: now), 'hace 3 h');
    expect(timeAgo(l, DateTime(2026, 11, 15, 9), now: now), 'ayer');
    expect(timeAgo(l, DateTime(2026, 11, 13, 9), now: now), 'hace 3 días');
    expect(timeAgo(l, DateTime(2026, 10, 23, 9), now: now), contains('2026'));
    expect(shortDate(DateTime(2026, 10, 23)), '23 oct 2026');
    expect(eventDate(DateTime(2026, 11, 20, 19)), contains('20'));
  });

  test('scrubText elimina datos personales antes de Sentry', () {
    final s = scrubText(
      'Error de ana.ortega@demo.es en /perfil/ana-ortega-123 token eyJhbGc.eyJzdWIi.sig id 01900000-0000-7000-8000-000000000001',
    );
    expect(s, isNot(contains('ana.ortega@')));
    expect(s, contains('[email]'));
    expect(s, contains('/perfil/[slug]'));
    expect(s, contains('[token]'));
    expect(s, contains('[id]'));
  });

  test('AppEnv', () {
    final env = AppEnv.fromEnvironment();
    expect(env.oidcProvider, 'custom:icex-alumni');
    expect(env.authRedirect, 'es.icexalumni.atlas://login-callback');
    expect(env.isProduction, isFalse);
    expect(env.hasSentry, isFalse);
    expect(env.mapTileUrl, contains('openstreetmap'));
  });

  test('AuthFailed detecta el rechazo del hook de membresía', () {
    expect(const AuthFailed('icex_member_not_verified').isNotMember, isTrue);
    expect(const AuthFailed('icex_member_not_active').isNotMember, isTrue);
    expect(const AuthFailed('network').isNotMember, isFalse);
  });

  group('WCAG 2.2 AA: contraste de colores del tema', () {
    test('texto normal ≥ 4.5:1', () {
      expect(contrast(IcexColors.foreground, IcexColors.page), greaterThan(4.5));
      expect(contrast(IcexColors.mutedForeground, IcexColors.card), greaterThan(4.5));
      expect(contrast(IcexColors.mutedForeground, IcexColors.page), greaterThan(4.5));
      expect(
        contrast(Colors.white, IcexColors.primary),
        greaterThan(4.5),
        reason: 'botones y ACTIVO',
      );
      expect(
        contrast(IcexColors.primary, IcexColors.card),
        greaterThan(4.5),
        reason: 'enlaces y badges de tipo',
      );
      expect(
        contrast(IcexColors.onAccent, IcexColors.promoTag),
        greaterThan(4.5),
        reason: 'badge de promoción',
      );
    });

    test('badges de fase (texto en negrita pequeño) ≥ 4.5:1', () {
      for (final f in Fase.values) {
        expect(
          contrast(IcexColors.onPhase(f), IcexColors.phase(f)),
          greaterThan(4.5),
          reason: f.label,
        );
      }
    });
  });
}
