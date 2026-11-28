import 'dart:typed_data';

import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/features/feed/application/post_interactions.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'feed_controller.g.dart';

class FeedState {
  const FeedState({
    required this.posts,
    this.destacadas = const [],
    this.nextCursor,
    this.loadingMore = false,
  });

  final List<Post> posts;
  final List<Post> destacadas;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  FeedState copyWith({
    List<Post>? posts,
    List<Post>? destacadas,
    String? Function()? nextCursor,
    bool? loadingMore,
  }) => FeedState(
    posts: posts ?? this.posts,
    destacadas: destacadas ?? this.destacadas,
    nextCursor: nextCursor == null ? this.nextCursor : nextCursor(),
    loadingMore: loadingMore ?? this.loadingMore,
  );

  FeedState replacePost(Post p) => copyWith(
    posts: [
      for (final x in posts)
        if (x.id == p.id) p else x,
    ],
    destacadas: [
      for (final x in destacadas)
        if (x.id == p.id) p else x,
    ],
  );
}

/// Pausa tras un fallo al paginar: el listener de scroll pide la página siguiente en cada
/// notificación, y sin pausa un fallo de red se convertía en una ráfaga de reintentos.
const _retryCooldown = Duration(seconds: 5);

/// Feed de Inicio. Se mantiene vivo mientras dura la sesión (no se recarga ni pierde la
/// paginación al cambiar de pestaña, como en LinkedIn o Instagram) y se descarta al cambiar
/// de usuario.
@Riverpod(keepAlive: true)
class FeedController extends _$FeedController {
  DateTime? _failedAt;

  @override
  Future<FeedState> build() async {
    ref.watch(sessionUserIdProvider);
    _failedAt = null;
    final page = await ref.watch(feedRepositoryProvider).feed();
    return FeedState(posts: page.items, destacadas: page.destacadas, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore || state.isLoading) return;
    final failed = _failedAt;
    if (failed != null && DateTime.now().difference(failed) < _retryCooldown) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await ref.read(feedRepositoryProvider).feed(cursor: s.nextCursor);
      if (!ref.mounted) return;
      _failedAt = null;
      final known = s.posts.map((p) => p.id).toSet();
      state = AsyncData(
        s.copyWith(
          posts: [...s.posts, ...page.items.where((p) => !known.contains(p.id))],
          nextCursor: () => page.nextCursor,
          loadingMore: false,
        ),
      );
    } on Object {
      _failedAt = DateTime.now();
      if (ref.mounted) state = AsyncData(s.copyWith(loadingMore: false));
    }
  }

  /// Recarga completa (tirar para refrescar).
  Future<void> refresh() async {
    ref.read(postOverridesProvider.notifier).clear();
    ref
      ..invalidate(suggestionsProvider)
      ..invalidate(communityHighlightsProvider)
      ..invalidateSelf();
    await future;
  }

  /// Publica (texto, foto opcional, tipo). Idempotente por UUIDv7: un reintento no duplica.
  Future<Post> publish({
    required String texto,
    PostTipo tipo = PostTipo.general,
    Uint8List? image,
    String? compartidoDe,
    String? id,
  }) async {
    final repo = ref.read(feedRepositoryProvider);
    final postId = id ?? ref.read(idGeneratorProvider).next();
    final media = image == null ? const <String>[] : [await repo.uploadImage(image)];
    final post = await repo.create(
      id: postId,
      texto: texto,
      tipo: tipo,
      media: media,
      compartidoDe: compartidoDe,
    );
    final s = state.value;
    if (s != null) {
      state = AsyncData(s.copyWith(posts: [post, ...s.posts.where((p) => p.id != post.id)]));
    }
    return post;
  }
}

/// Un feed con menos publicaciones que esto se considera «en frío»: se completa con lo
/// destacado de la comunidad para que quien acaba de llegar tenga algo que leer.
const coldFeedThreshold = 5;

/// «Destacado en la comunidad» (posts de gente a la que aún no sigues).
@Riverpod(keepAlive: true)
Future<List<Post>> communityHighlights(Ref ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(feedRepositoryProvider).highlights();
}

@Riverpod(keepAlive: true)
Future<CommunityStats> communityStats(Ref ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(socialRepositoryProvider).communityStats();
}

@Riverpod(keepAlive: true)
class Suggestions extends _$Suggestions {
  @override
  Future<List<ProfileCard>> build() {
    ref.watch(sessionUserIdProvider);
    return ref.watch(socialRepositoryProvider).suggestions();
  }

  /// Seguir / dejar de seguir desde la tarjeta de sugerencia (optimista).
  Future<void> toggleFollow(ProfileCard p) async {
    final next = !p.isFollowing;
    _replace(p.copyWith(isFollowing: next));
    try {
      final social = ref.read(socialRepositoryProvider);
      next ? await social.follow(p.userId) : await social.unfollow(p.userId);
    } on Object {
      if (ref.mounted) _replace(p);
      rethrow;
    }
  }

  /// Descartar una sugerencia (solo en este dispositivo, hasta la próxima recarga).
  void dismiss(ProfileCard p) => state = AsyncData([
    for (final x in state.value ?? const <ProfileCard>[])
      if (x.userId != p.userId) x,
  ]);

  void _replace(ProfileCard p) => state = AsyncData([
    for (final x in state.value ?? const <ProfileCard>[])
      if (x.userId == p.userId) p else x,
  ]);
}

@riverpod
class NewsController extends _$NewsController {
  @override
  Future<FeedState> build() async {
    final page = await ref.watch(feedRepositoryProvider).news();
    return FeedState(posts: page.items, destacadas: page.destacadas, nextCursor: page.nextCursor);
  }

  DateTime? _failedAt;

  /// Antes, si esta llamada fallaba, `loadingMore` se quedaba en `true` para siempre y ya no
  /// se cargaban más novedades.
  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    final failed = _failedAt;
    if (failed != null && DateTime.now().difference(failed) < _retryCooldown) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await ref.read(feedRepositoryProvider).news(cursor: s.nextCursor);
      if (!ref.mounted) return;
      _failedAt = null;
      state = AsyncData(
        s.copyWith(
          posts: [...s.posts, ...page.items],
          nextCursor: () => page.nextCursor,
          loadingMore: false,
        ),
      );
    } on Object {
      _failedAt = DateTime.now();
      if (ref.mounted) state = AsyncData(s.copyWith(loadingMore: false));
    }
  }
}
