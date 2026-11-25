import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';

/// Registro del token FCM (APNs en iOS vía FCM) y navegación al tocar una notificación.
/// Si Firebase no está configurado (desarrollo local), no hace nada.
class PushService {
  PushService(this._ref);

  final Ref _ref;
  final _subs = <StreamSubscription<Object?>>[];
  String? _token;

  Future<void> start() async {
    if (Firebase.apps.isEmpty) return;
    final fm = FirebaseMessaging.instance;
    final perm = await fm.requestPermission();
    if (perm.authorizationStatus == AuthorizationStatus.denied) return;
    // API de firebase_messaging 17: register() + onRegistered (token inicial y rotaciones).
    _subs
      ..add(fm.onRegistered.listen((t) => unawaited(_register(t))))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen(_open));
    await fm.register();
    final initial = await fm.getInitialMessage();
    if (initial != null) _open(initial);
  }

  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    final t = _token;
    if (t != null) {
      try {
        await _ref.read(notificationsRepositoryProvider).unregisterPushToken(t);
      } on Object {
        // sesión ya cerrada
      }
    }
  }

  Future<void> _register(String? token) async {
    if (token == null) return;
    _token = token;
    await _ref
        .read(notificationsRepositoryProvider)
        .registerPushToken(token, platform: Platform.isIOS ? 'ios' : 'android');
  }

  void _open(RemoteMessage m) {
    final route = m.data['route'];
    if (route is String && route.startsWith('/')) {
      unawaited(_ref.read(appRouterProvider).push<void>(route));
    }
  }
}

final pushServiceProvider = Provider<PushService?>((ref) {
  if (ref.watch(sessionUserIdProvider) == null) return null;
  final s = PushService(ref);
  unawaited(s.start());
  ref.onDispose(() => unawaited(s.stop()));
  return s;
});
