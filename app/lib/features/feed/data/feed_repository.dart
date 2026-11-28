import 'dart:typed_data';

import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/core/api/page.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';

class FeedRepository {
  const FeedRepository(this._api);

  final ApiClient _api;

  Future<FeedPage> feed({String? cursor, int limit = 20}) async =>
      FeedPage.fromJson(await _api.rpcJson('get_feed', {'p_cursor': cursor, 'p_limit': limit}));

  /// Lo más interesante de los últimos días de gente a la que aún no sigues (arranque en frío).
  Future<List<Post>> highlights({int limit = 10}) async =>
      (await _api.rpcList('community_highlights', {'p_limit': limit})).map(Post.fromJson).toList();

  Future<FeedPage> news({String? cursor}) async =>
      FeedPage.fromJson(await _api.rpcJson('get_news', {'p_cursor': cursor}));

  Future<CursorPage<Post>> userPosts(String userId, {String? cursor}) async => CursorPage.fromJson(
    await _api.rpcJson('get_user_posts', {'p_user': userId, 'p_cursor': cursor}),
    Post.fromJson,
  );

  Future<Post> post(String id) async => Post.fromJson(await _api.rpcJson('get_post', {'p_id': id}));

  /// Idempotente: el id (UUIDv7) lo genera la app, así un reintento no duplica.
  Future<Post> create({
    required String id,
    required String texto,
    PostTipo tipo = PostTipo.general,
    List<String> media = const [],
    String? clubId,
    String? compartidoDe,
  }) async => Post.fromJson(
    await _api.rpcJson('create_post', {
      'p_id': id,
      'p_texto': texto,
      'p_tipo': tipo.code,
      'p_media': media,
      'p_club_id': clubId,
      'p_compartido_de': compartidoDe,
    }),
  );

  Future<void> delete(String id) => _api.rpc('delete_post', {'p_id': id});

  Future<String> uploadImage(Uint8List bytes) => _api.uploadImage(bytes, bucket: 'post-media');

  Future<({bool recomendado, int count})> setRecommended(
    String postId, {
    required bool value,
  }) async {
    final r = await _api.rpcJson(value ? 'recommend' : 'unrecommend', {'p_post': postId});
    return (
      recomendado: r['recomendado'] as bool,
      count: (r['recomendaciones_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<CursorPage<Comment>> comments(String postId, {String? cursor}) async =>
      CursorPage.fromJson(
        await _api.rpcJson('get_comments', {'p_post': postId, 'p_cursor': cursor}),
        Comment.fromJson,
      );

  Future<Comment> addComment({
    required String id,
    required String postId,
    required String texto,
  }) async => Comment.fromJson(
    await _api.rpcJson('add_comment', {'p_id': id, 'p_post': postId, 'p_texto': texto}),
  );

  Future<void> deleteComment(String id) => _api.rpc('delete_comment', {'p_id': id});
}
