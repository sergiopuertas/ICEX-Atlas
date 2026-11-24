import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/core/utils/time_ago.dart';
import 'package:icex_atlas/features/notifications/application/unread_counts.dart';
import 'package:icex_atlas/features/notifications/data/notifications_repository.dart';
import 'package:icex_atlas/features/notifications/domain/app_notification.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'notifications_page.g.dart';

@riverpod
class NotificationsController extends _$NotificationsController {
  @override
  Future<NotificationsResult> build() => ref.watch(notificationsRepositoryProvider).list();

  void _markLocal(bool Function(AppNotification) which) {
    final v = state.value;
    if (v == null) return;
    final items = [
      for (final n in v.items)
        if (which(n)) n.markedRead() else n,
    ];
    state = AsyncData(
      NotificationsResult(
        items: items,
        nextCursor: v.nextCursor,
        unread: items.where((n) => !n.leido).length,
      ),
    );
  }

  /// Optimista: se marcan al instante y se sincroniza en segundo plano.
  Future<void> markAllRead() async {
    final before = state.value;
    _markLocal((_) => true);
    try {
      await ref.read(notificationsRepositoryProvider).markRead();
      if (ref.mounted) await ref.read(unreadProvider.notifier).refresh();
    } on Object {
      if (ref.mounted && before != null) state = AsyncData(before);
      rethrow;
    }
  }

  /// Marca como leída sin bloquear la navegación (un fallo de red ya no impide abrirla).
  void open(AppNotification n) {
    if (n.leido) return;
    _markLocal((x) => x.id == n.id);
    ref
        .read(notificationsRepositoryProvider)
        .markRead([n.id])
        .then(
          (_) => ref.mounted ? ref.read(unreadProvider.notifier).refresh() : null,
          onError: (Object _) {},
        )
        .ignore();
  }
}

/// Texto de una notificación agrupada: "Ana y 3 más recomendaron tu publicación".
String notificationText(AppLocalizations l, AppNotification n) {
  final name = n.actores.isEmpty ? 'Un alumni' : n.actores.first.nombre;
  final others = n.total - 1;
  return switch (n.tipo) {
    NotificationTipo.nuevoSeguidor =>
      others > 0 ? l.notifFollowMany(name, others) : l.notifFollow(name),
    NotificationTipo.recomendacion =>
      others > 0 ? l.notifRecommendationMany(name, others) : l.notifRecommendation(name),
    NotificationTipo.comentario =>
      others > 0 ? l.notifCommentMany(name, others) : l.notifComment(name),
    NotificationTipo.novedad => l.notifNews(n.payload['titulo'] as String? ?? ''),
    _ => l.notifGeneric,
  };
}

IconData _typeIcon(NotificationTipo t) => switch (t) {
  NotificationTipo.nuevoSeguidor => Icons.person_add_alt_1_rounded,
  NotificationTipo.recomendacion => Icons.favorite_rounded,
  NotificationTipo.comentario => Icons.mode_comment_rounded,
  NotificationTipo.mensaje => Icons.chat_bubble_rounded,
  NotificationTipo.evento => Icons.event_rounded,
  NotificationTipo.novedad => Icons.campaign_rounded,
  NotificationTipo.sistema => Icons.info_rounded,
};

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final s = ref.watch(notificationsControllerProvider);
    final c = ref.read(notificationsControllerProvider.notifier);
    final hasUnread = s.value?.items.any((n) => !n.leido) ?? false;
    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Semantics(header: true, child: Text(text, style: t.titleSmall)),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () async {
                try {
                  await c.markAllRead();
                } on Object catch (e) {
                  if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
                }
              },
              child: Text(l.markAllRead),
            ),
        ],
      ),
      body: switch (s) {
        AsyncValue(:final value?) when value.items.isEmpty => EmptyState(
          message: l.notificationsEmpty,
          icon: Icons.notifications_none,
        ),
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () => ref.refresh(notificationsControllerProvider.future),
          child: Builder(
            builder: (context) {
              final fresh = value.items.where((n) => !n.leido).toList();
              final old = value.items.where((n) => n.leido).toList();
              return ListView(
                children: [
                  if (fresh.isNotEmpty) ...[
                    header(l.notificationsNew),
                    for (final n in fresh) _NotificationTile(n: n, onOpen: c.open),
                  ],
                  if (old.isNotEmpty) ...[
                    header(l.notificationsEarlier),
                    for (final n in old) _NotificationTile(n: n, onOpen: c.open),
                  ],
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
        ),
        AsyncValue(:final error?) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(notificationsControllerProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.n, required this.onOpen});

  final AppNotification n;
  final ValueChanged<AppNotification> onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final leading = n.actores.isNotEmpty
        ? Avatar.of(n.actores.first, size: 48, ring: true)
        : const CircleAvatar(
            radius: 24,
            backgroundColor: IcexColors.primary,
            foregroundColor: Colors.white,
            child: Icon(Icons.campaign_outlined),
          );
    return Material(
      color: n.leido ? IcexColors.card : IcexColors.primary.withValues(alpha: 0.04),
      child: InkWell(
        onTap: () {
          onOpen(n);
          unawaited(context.push(n.route));
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    leading,
                    if (n.actores.isNotEmpty)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: IcexColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Icon(_typeIcon(n.tipo), size: 11, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notificationText(l, n),
                      style: t.bodyMedium?.copyWith(
                        fontWeight: n.leido ? FontWeight.w400 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(timeAgo(l, n.updatedAt), style: t.bodySmall),
                  ],
                ),
              ),
              if (!n.leido)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 8),
                  decoration: const BoxDecoration(
                    color: IcexColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
