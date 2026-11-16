import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';

/// Heartbeat cada 60 s con la app en primer plano: el push-dispatcher solo envía push de
/// mensajes a quien no está conectado (lo demás llega por Realtime). Al volver a primer
/// plano reintenta los mensajes pendientes del outbox.
class Presence with WidgetsBindingObserver {
  Presence(this._beat, this._flushOutbox);

  final Future<void> Function() _beat;
  final Future<void> Function() _flushOutbox;
  Timer? _timer;

  static const interval = Duration(seconds: 60);

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resume();
    } else {
      _timer?.cancel();
    }
  }

  void _resume() {
    _timer?.cancel();
    unawaited(_safe(_beat));
    unawaited(_safe(_flushOutbox));
    _timer = Timer.periodic(interval, (_) => unawaited(_safe(_beat)));
  }

  static Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } on Object {
      // sin conexión: se reintentará
    }
  }
}

final presenceProvider = Provider<Presence?>((ref) {
  final session = ref.watch(sessionControllerProvider);
  if (session is! SignedIn) return null;
  final p = Presence(() => ref.read(messagingRepositoryProvider).heartbeat(), () async {
    await ref.read(messageOutboxProvider).flush();
  })..start();
  ref.onDispose(p.stop);
  return p;
});
