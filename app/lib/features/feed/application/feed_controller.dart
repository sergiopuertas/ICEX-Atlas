import 'dart:typed_data';

import 'package:icex_atlas/core/providers.dart';
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

@riverpod
class FeedController extends _$FeedController {
  @override
  Future<FeedState> build() async {
    final page = await ref.watch(feedRepositoryProvider).feed();
    return FeedState(posts: page.items, destacadas: page.destacadas, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    try {
      final page = await ref.read(feedRepositoryProvider).feed(cursor: s.nextCursor);
      state = AsyncData(
        s.copyWith(
          posts: [...s.posts, ...page.items],
          nextCursor: () => page.nextCursor,
          loadingMore: false,
        ),
      );
    } on Object {
      state = AsyncData(s.copyWith(loadingMore: false));
      rethrow;
    }
  }

  /// Recomendar con actualización optimista; si falla, se revierte.
  Future<void> toggleRecommend(Post post) async {
    final s = state.value;
    if (s == null) return;
    final optimistic = post.toggleRecommendation();
    state = AsyncData(s.replacePost(optimistic));
    try {
      final r = await ref
          .read(feedRepositoryProvider)
          .setRecommended(post.id, value: optimistic.recomendado);
      state = AsyncData(
        state.value!.replacePost(
          optimistic.copyWith(recomendado: r.recomendado, recomendacionesCount: r.count),
        ),
      );
    } on Object {
      state = AsyncData(state.value!.replacePost(post));
      rethrow;
    }
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

  Future<void> delete(Post post) async {
    await ref.read(feedRepositoryProvider).delete(post.id);
    final s = state.value;
    if (s != null) {
      state = AsyncData(s.copyWith(posts: s.posts.where((p) => p.id != post.id).toList()));
    }
  }

  void updateComments(String postId, int count) {
    final s = state.value;
    if (s == null) return;
    final p = [...s.posts, ...s.destacadas].where((x) => x.id == postId).firstOrNull;
    if (p != null) state = AsyncData(s.replacePost(p.copyWith(comentariosCount: count)));
  }
}

@riverpod
Future<CommunityStats> communityStats(Ref ref) =>
    ref.watch(socialRepositoryProvider).communityStats();

@riverpod
class Suggestions extends _$Suggestions {
  @override
  Future<List<ProfileCard>> build() => ref.watch(socialRepositoryProvider).suggestions();

  Future<void> follow(ProfileCard p) async {
    final current = state.value ?? const [];
    state = AsyncData([
      for (final x in current)
        if (x.userId == p.userId) x.copyWith(isFollowing: true) else x,
    ]);
    try {
      await ref.read(socialRepositoryProvider).follow(p.userId);
    } on Object {
      state = AsyncData(current);
      rethrow;
    }
  }
}

@riverpod
class NewsController extends _$NewsController {
  @override
  Future<FeedState> build() async {
    final page = await ref.watch(feedRepositoryProvider).news();
    return FeedState(posts: page.items, destacadas: page.destacadas, nextCursor: page.nextCursor);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData(s.copyWith(loadingMore: true));
    final page = await ref.read(feedRepositoryProvider).news(cursor: s.nextCursor);
    state = AsyncData(
      s.copyWith(
        posts: [...s.posts, ...page.items],
        nextCursor: () => page.nextCursor,
        loadingMore: false,
      ),
    );
  }
}
