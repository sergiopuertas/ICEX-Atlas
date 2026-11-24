import 'dart:async';

import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unread_counts.g.dart';

typedef UnreadCounts = ({int mensajes, int notificaciones});

/// No leídos (mensajes y notificaciones) para los badges. Se refresca con los eventos
/// del canal privado `user:<id>` de Realtime.
@Riverpod(keepAlive: true)
class Unread extends _$Unread {
  @override
  Future<UnreadCounts> build() async {
    final userId = ref.watch(sessionUserIdProvider);
    if (userId == null) return (mensajes: 0, notificaciones: 0);
    final sub = ref
        .watch(realtimeGatewayProvider)
        .userEvents(userId)
        .listen((_) => unawaited(refresh()));
    ref.onDispose(sub.cancel);
    return await ref.read(notificationsRepositoryProvider).unreadCounts();
  }

  Future<void> refresh() async {
    try {
      final c = await ref.read(notificationsRepositoryProvider).unreadCounts();
      if (ref.mounted) state = AsyncData(c);
    } on Object {
      // conservar el último valor
    }
  }
}
