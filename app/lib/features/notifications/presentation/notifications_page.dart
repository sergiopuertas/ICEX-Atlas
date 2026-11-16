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

  Future<void> markAllRead() async {
    await ref.read(notificationsRepositoryProvider).markRead();
    ref.invalidateSelf();
    await ref.read(unreadProvider.notifier).refresh();
  }

  Future<void> open(AppNotification n) async {
    if (!n.leido) {
      await ref.read(notificationsRepositoryProvider).markRead([n.id]);
      await ref.read(unreadProvider.notifier).refresh();
    }
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

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(notificationsControllerProvider);
    final c = ref.read(notificationsControllerProvider.notifier);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notificationsTitle),
        actions: [TextButton(onPressed: c.markAllRead, child: Text(l.markAllRead))],
      ),
      body: switch (s) {
        AsyncData(:final value) when value.items.isEmpty => EmptyState(
          message: l.notificationsEmpty,
          icon: Icons.notifications_none,
        ),
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(notificationsControllerProvider.future),
          child: ListView.separated(
            itemCount: value.items.length,
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (_, i) {
              final n = value.items[i];
              return ListTile(
                tileColor: n.leido ? null : IcexColors.secondary,
                leading: n.actores.isNotEmpty
                    ? Avatar.of(n.actores.first, ring: true)
                    : const CircleAvatar(
                        backgroundColor: IcexColors.primary,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.campaign_outlined),
                      ),
                title: Text(
                  notificationText(l, n),
                  style: TextStyle(fontWeight: n.leido ? FontWeight.w400 : FontWeight.w600),
                ),
                subtitle: Text(timeAgo(l, n.updatedAt)),
                onTap: () async {
                  await c.open(n);
                  if (context.mounted) await context.push(n.route);
                },
              );
            },
          ),
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(notificationsControllerProvider),
        ),
        _ => const LoadingView(),
      },
    );
  }
}
