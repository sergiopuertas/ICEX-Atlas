import 'dart:async';

import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/utils/debouncer.dart';
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
    // Una ráfaga de eventos (varios mensajes seguidos) = una sola consulta de contadores.
    final burst = Debouncer(realtimeBurstWindow);
    final sub = ref
        .watch(realtimeGatewayProvider)
        .userEvents(userId)
        .listen((_) => burst(() => unawaited(refresh())));
    ref.onDispose(() {
      burst.dispose();
      unawaited(sub.cancel());
    });
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
