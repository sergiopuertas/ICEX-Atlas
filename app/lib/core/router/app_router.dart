import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/features/auth/presentation/login_page.dart';
import 'package:icex_atlas/features/directory/presentation/network_page.dart';
import 'package:icex_atlas/features/feed/presentation/compose_page.dart';
import 'package:icex_atlas/features/feed/presentation/home_page.dart';
import 'package:icex_atlas/features/feed/presentation/news_page.dart';
import 'package:icex_atlas/features/feed/presentation/post_detail_page.dart';
import 'package:icex_atlas/features/map/presentation/club_page.dart';
import 'package:icex_atlas/features/map/presentation/map_page.dart';
import 'package:icex_atlas/features/messaging/presentation/chat_page.dart';
import 'package:icex_atlas/features/messaging/presentation/conversations_page.dart';
import 'package:icex_atlas/features/notifications/presentation/notifications_page.dart';
import 'package:icex_atlas/features/orientador/presentation/orientador_page.dart';
import 'package:icex_atlas/features/profiles/presentation/edit_profile_page.dart';
import 'package:icex_atlas/features/profiles/presentation/profile_page.dart';
import 'package:icex_atlas/features/settings/presentation/settings_pages.dart';
import 'package:icex_atlas/shared/widgets/app_shell.dart';
import 'package:icex_atlas/shared/widgets/common.dart';

/// Rutas con nombre de la app (también usadas en deep links y payloads de push).
abstract final class Routes {
  static const login = '/login';
  static const accessDenied = '/acceso-denegado';
  static const splash = '/cargando';
  static const home = '/';
  static const network = '/red';
  static const map = '/mapa';
  static const messages = '/mensajes';
  static const orientador = '/orientador';
  static const news = '/novedades';
  static const notifications = '/notificaciones';
  static const settings = '/ajustes';
  static const editProfile = '/perfil/editar';
  static const compose = '/publicar';

  static String profile(String slug) => '/perfil/$slug';
  static String chat(String conversationId) => '/mensajes/$conversationId';

  /// Deep link del mockup: `/mensajes?to=<slug|user_id>`
  static String chatWith(String userId) => '/mensajes/nuevo?to=$userId';
  static String post(String id) => '/post/$id';
  static String club(String id) => '/clubs/$id';
}

/// Decide la ruta según el estado de sesión. Pura → testeable.
String? redirectFor(SessionState session, Uri location) {
  final path = location.path;
  final public = path == Routes.login || path == Routes.accessDenied;
  return switch (session) {
    SessionUnknown() => path == Routes.splash ? null : Routes.splash,
    AccessDenied() => path == Routes.accessDenied ? null : Routes.accessDenied,
    SignedOut() || SigningIn() => path == Routes.login ? null : Routes.login,
    SignedIn() when public || path == Routes.splash => Routes.home,
    SignedIn() => _legacyChatRedirect(location),
  };
}

/// `/mensajes?to=<id>` (enlace "Enviar" del mockup) → chat nuevo.
String? _legacyChatRedirect(Uri location) {
  final to = location.queryParameters['to'];
  if (location.path == Routes.messages && to != null && to.isNotEmpty) return Routes.chatWith(to);
  return null;
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<SessionState>(ref.read(sessionControllerProvider));
  ref
    ..listen(sessionControllerProvider, (_, next) => refresh.value = next)
    ..onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) => redirectFor(refresh.value, state.uri),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => const Scaffold(body: LoadingView()),
      ),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginPage()),
      GoRoute(path: Routes.accessDenied, builder: (_, _) => const AccessDeniedPage()),
      // Una rama (y un Navigator) por pestaña: al cambiar de pestaña cada una conserva su
      // estado, su scroll y sus datos, como en Instagram o LinkedIn. Con el ShellRoute
      // anterior cada cambio destruía la página: el feed se recargaba, se perdía la posición
      // y el Orientador olvidaba sus respuestas.
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomePage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.network, builder: (_, _) => const NetworkPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.map, builder: (_, _) => const MapPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.messages, builder: (_, _) => const ConversationsPage())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.orientador, builder: (_, _) => const OrientadorPage())],
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/mensajes/nuevo',
        builder: (_, s) => ChatPage(toUserId: s.uri.queryParameters['to']),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: '/mensajes/:id',
        builder: (_, s) => ChatPage(conversationId: s.pathParameters['id']),
      ),
      GoRoute(
        path: Routes.compose,
        builder: (_, s) => ComposePage(initial: s.extra),
      ),
      GoRoute(path: Routes.news, builder: (_, _) => const NewsPage()),
      GoRoute(path: Routes.notifications, builder: (_, _) => const NotificationsPage()),
      GoRoute(path: Routes.editProfile, builder: (_, _) => const EditProfilePage()),
      GoRoute(
        path: '/perfil/:slug',
        builder: (_, s) => ProfilePage(slug: s.pathParameters['slug']!),
      ),
      GoRoute(
        path: '/post/:id',
        builder: (_, s) => PostDetailPage(postId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/clubs/:id',
        builder: (_, s) => ClubPage(clubId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsPage(),
        routes: [
          GoRoute(path: 'notificaciones', builder: (_, _) => const NotificationPrefsPage()),
          GoRoute(path: 'privacidad', builder: (_, _) => const PrivacyPage()),
          GoRoute(path: 'bloqueados', builder: (_, _) => const BlockedPage()),
        ],
      ),
    ],
  );
});
