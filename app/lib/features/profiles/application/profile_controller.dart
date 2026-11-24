import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/features/feed/application/feed_controller.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_controller.g.dart';

@riverpod
class ProfileController extends _$ProfileController {
  @override
  Future<ProfileDetail> build(String slug) =>
      ref.watch(profilesRepositoryProvider).getProfile(slug: slug);

  /// Seguir / dejar de seguir: el botón cambia al instante y después se recarga el perfil
  /// (al seguir pueden aparecer campos visibles solo para seguidores).
  Future<void> toggleFollow() async {
    final p = state.value;
    if (p == null) return;
    final next = !p.card.isFollowing;
    state = AsyncData(
      p.copyWith(
        card: p.card.copyWith(
          isFollowing: next,
          seguidoresCount: p.card.seguidoresCount + (next ? 1 : -1),
        ),
      ),
    );
    try {
      final social = ref.read(socialRepositoryProvider);
      next ? await social.follow(p.card.userId) : await social.unfollow(p.card.userId);
    } on Object {
      if (ref.mounted) state = AsyncData(p);
      rethrow;
    }
    try {
      final fresh = await ref.read(profilesRepositoryProvider).getProfile(slug: slug);
      if (ref.mounted) state = AsyncData(fresh);
    } on Object {
      // Nos quedamos con el estado optimista.
    }
  }

  Future<void> block() async {
    final p = state.value;
    if (p == null) return;
    await ref.read(socialRepositoryProvider).block(p.card.userId);
    // Que desaparezcan sus publicaciones y sugerencias sin tener que recargar a mano.
    ref
      ..invalidate(feedControllerProvider)
      ..invalidate(suggestionsProvider);
  }
}

@riverpod
Future<List<Post>> userPosts(Ref ref, String userId) async =>
    (await ref.watch(feedRepositoryProvider).userPosts(userId)).items;
