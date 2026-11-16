import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_controller.g.dart';

@riverpod
class ProfileController extends _$ProfileController {
  @override
  Future<ProfileDetail> build(String slug) =>
      ref.watch(profilesRepositoryProvider).getProfile(slug: slug);

  Future<void> toggleFollow() async {
    final p = state.value;
    if (p == null) return;
    final social = ref.read(socialRepositoryProvider);
    final r = p.card.isFollowing
        ? await social.unfollow(p.card.userId)
        : await social.follow(p.card.userId);
    // Recargar: con "seguir" pueden aparecer campos visibles solo a seguidores.
    state = AsyncData(await ref.read(profilesRepositoryProvider).getProfile(slug: slug));
    assert(state.value?.card.isFollowing == r.isFollowing, 'estado de seguimiento coherente');
  }

  Future<void> block() async {
    final p = state.value;
    if (p == null) return;
    await ref.read(socialRepositoryProvider).block(p.card.userId);
  }
}

@riverpod
Future<List<Post>> userPosts(Ref ref, String userId) async =>
    (await ref.watch(feedRepositoryProvider).userPosts(userId)).items;
