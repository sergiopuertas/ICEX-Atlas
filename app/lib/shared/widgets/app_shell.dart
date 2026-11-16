import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/notifications/application/unread_counts.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/common.dart';

/// Barra superior (logo, Novedades, notificaciones, avatar) + navegación inferior móvil:
/// Inicio · Red · Mapa · Mensajes · Orientador.
class AppShell extends ConsumerWidget {
  const AppShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  static const List<String> _tabs = [
    Routes.home,
    Routes.network,
    Routes.map,
    Routes.messages,
    Routes.orientador,
  ];

  int get _index {
    final i = _tabs.lastIndexWhere((t) => t == '/' ? location == '/' : location.startsWith(t));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final unread = ref.watch(unreadProvider).value ?? (mensajes: 0, notificaciones: 0);
    final session = ref.watch(sessionControllerProvider);
    final me = session is SignedIn ? session.me : null;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: 16,
        title: Semantics(
          button: true,
          label: l.navHome,
          child: GestureDetector(onTap: () => context.go(Routes.home), child: const IcexLogo()),
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(4), child: IcexStripe()),
        actions: [
          IconButton(
            tooltip: l.navNews,
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => context.push(Routes.news),
          ),
          IconButton(
            tooltip: l.navNotifications,
            icon: CountBadge(
              count: unread.notificaciones,
              child: const Icon(Icons.notifications_none),
            ),
            onPressed: () => context.push(Routes.notifications),
          ),
          if (me != null)
            Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: Semantics(
                button: true,
                label: '${l.navProfile}: ${me.profile.card.nombre}',
                child: InkResponse(
                  onTap: () => context.push(Routes.profile(me.profile.card.slug)),
                  child: Avatar.of(me.profile.card, size: 34, ring: true),
                ),
              ),
            ),
        ],
      ),
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: IcexColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => context.go(_tabs[i]),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home),
              label: l.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.group_outlined),
              selectedIcon: const Icon(Icons.group),
              label: l.navNetwork,
            ),
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map),
              label: l.navMap,
            ),
            NavigationDestination(
              icon: CountBadge(
                count: unread.mensajes,
                child: const Icon(Icons.chat_bubble_outline),
              ),
              selectedIcon: CountBadge(
                count: unread.mensajes,
                child: const Icon(Icons.chat_bubble),
              ),
              label: l.navMessages,
              tooltip: unread.mensajes > 0
                  ? '${l.navMessages}, ${l.unreadBadge(unread.mensajes)}'
                  : null,
            ),
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore),
              label: l.navOrientador,
            ),
          ],
        ),
      ),
    );
  }
}
