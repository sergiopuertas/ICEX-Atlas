import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/notifications/application/unread_counts.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/brand.dart';

/// Pestañas de la navegación inferior (orden de las ramas del router).
enum AppTab { home, network, map, messages, orientador }

/// Se emite al tocar la pestaña que ya está activa. Las páginas con scroll lo escuchan para
/// volver arriba (comportamiento estándar en Instagram, LinkedIn o X).
class TabReselected extends Notifier<({AppTab tab, int tick})?> {
  @override
  ({AppTab tab, int tick})? build() => null;

  void fire(AppTab tab) => state = (tab: tab, tick: (state?.tick ?? 0) + 1);
}

final tabReselectedProvider = NotifierProvider<TabReselected, ({AppTab tab, int tick})?>(
  TabReselected.new,
);

/// Vuelve arriba [controller] cuando se toca de nuevo la pestaña [tab].
void listenScrollToTop(WidgetRef ref, AppTab tab, ScrollController controller) {
  ref.listen(tabReselectedProvider, (_, e) {
    if (e?.tab != tab || !controller.hasClients) return;
    if (controller.offset == 0) return;
    controller.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  });
}

/// Barra superior (logo, Novedades, notificaciones, avatar) + navegación inferior móvil:
/// Inicio · Red · Mapa · Mensajes · Orientador.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _select(WidgetRef ref, int i) {
    if (i == navigationShell.currentIndex) {
      // Segundo toque: volver a la raíz de la pestaña y arriba del todo.
      ref.read(tabReselectedProvider.notifier).fire(AppTab.values[i]);
      navigationShell.goBranch(i, initialLocation: true);
      return;
    }
    unawaited(HapticFeedback.selectionClick());
    navigationShell.goBranch(i);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final unread = ref.watch(unreadProvider).value ?? (mensajes: 0, notificaciones: 0);
    final session = ref.watch(sessionControllerProvider);
    final me = session is SignedIn ? session.me : null;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 56,
        titleSpacing: 16,
        title: Semantics(
          button: true,
          label: l.navHome,
          child: GestureDetector(
            onTap: () => _select(ref, 0),
            behavior: HitTestBehavior.opaque,
            // Zona táctil de 48 dp aunque el logo mida menos.
            child: const SizedBox(
              height: 48,
              child: Align(
                alignment: Alignment.centerLeft,
                widthFactor: 1,
                child: LogoBadge(height: 20, shadow: false),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: l.navNews,
            icon: const Icon(Icons.campaign_outlined),
            onPressed: () => context.push(Routes.news),
          ),
          IconButton(
            tooltip: unread.notificaciones > 0
                ? '${l.navNotifications}, ${l.unreadBadge(unread.notificaciones)}'
                : l.navNotifications,
            icon: CountBadge(
              count: unread.notificaciones,
              onDark: true,
              child: const Icon(Icons.notifications_none_rounded),
            ),
            onPressed: () => context.push(Routes.notifications),
          ),
          if (me != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                label: '${l.navProfile}: ${me.profile.card.nombre}',
                excludeSemantics: true,
                child: InkResponse(
                  radius: 24,
                  onTap: () => context.push(Routes.profile(me.profile.card.slug)),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Center(child: Avatar.of(me.profile.card, size: 32, ring: true)),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: IcexColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (i) => _select(ref, i),
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: l.navHome,
            ),
            NavigationDestination(
              icon: const Icon(Icons.group_outlined),
              selectedIcon: const Icon(Icons.group_rounded),
              label: l.navNetwork,
            ),
            NavigationDestination(
              icon: const Icon(Icons.public_outlined),
              selectedIcon: const Icon(Icons.public_rounded),
              label: l.navMap,
            ),
            NavigationDestination(
              icon: CountBadge(
                count: unread.mensajes,
                child: const Icon(Icons.chat_bubble_outline_rounded),
              ),
              selectedIcon: CountBadge(
                count: unread.mensajes,
                child: const Icon(Icons.chat_bubble_rounded),
              ),
              label: l.navMessages,
              tooltip: unread.mensajes > 0
                  ? '${l.navMessages}, ${l.unreadBadge(unread.mensajes)}'
                  : null,
            ),
            NavigationDestination(
              icon: const Icon(Icons.explore_outlined),
              selectedIcon: const Icon(Icons.explore_rounded),
              label: l.navOrientador,
            ),
          ],
        ),
      ),
    );
  }
}
