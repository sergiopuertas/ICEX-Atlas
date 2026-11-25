import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/profiles/application/profile_controller.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:icex_atlas/shared/widgets/follow_button.dart';

/// Seguidores / Siguiendo de un perfil (se abre al tocar los números del perfil).
class FollowsPage extends ConsumerWidget {
  const FollowsPage({required this.slug, this.showFollowing = false, super.key});

  final String slug;
  final bool showFollowing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileControllerProvider(slug));
    return profile.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: ErrorView(error: e),
      ),
      data: (p) => DefaultTabController(
        length: 2,
        initialIndex: showFollowing ? 1 : 0,
        child: Scaffold(
          appBar: AppBar(
            title: Text(p.card.nombre),
            bottom: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: IcexColors.accent,
              tabs: [
                Tab(text: '${compactNumber(p.card.seguidoresCount)} ${l.followers.toLowerCase()}'),
                Tab(text: '${compactNumber(p.card.siguiendoCount)} ${l.following.toLowerCase()}'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _FollowsList(
                key: const Key('followers-list'),
                slug: slug,
                userId: p.card.userId,
                following: false,
              ),
              _FollowsList(
                key: const Key('following-list'),
                slug: slug,
                userId: p.card.userId,
                following: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowsList extends ConsumerStatefulWidget {
  const _FollowsList({
    required this.slug,
    required this.userId,
    required this.following,
    super.key,
  });

  final String slug;
  final String userId;
  final bool following;

  @override
  ConsumerState<_FollowsList> createState() => _FollowsListState();
}

class _FollowsListState extends ConsumerState<_FollowsList> with AutomaticKeepAliveClientMixin {
  final _people = <ProfileCard>[];
  final _busy = <String>{};
  String? _cursor;
  bool _loading = false;
  bool _done = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading || (_done && !reset)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref
          .read(profilesRepositoryProvider)
          .listFollows(widget.userId, following: widget.following, cursor: reset ? null : _cursor);
      if (!mounted) return;
      setState(() {
        if (reset) _people.clear();
        _people.addAll(page.items);
        _cursor = page.nextCursor;
        _done = page.nextCursor == null;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(ProfileCard p) async {
    if (!_busy.add(p.userId)) return; // un toque a la vez por persona
    final l = AppLocalizations.of(context);
    final social = ref.read(socialRepositoryProvider);
    void replace(ProfileCard c) {
      final i = _people.indexWhere((x) => x.userId == c.userId);
      if (i >= 0) setState(() => _people[i] = c);
    }

    replace(p.copyWith(isFollowing: !p.isFollowing)); // optimista
    try {
      p.isFollowing ? await social.unfollow(p.userId) : await social.follow(p.userId);
      // Los números de mi perfil (y del que estoy viendo) han cambiado.
      ref.invalidate(profileControllerProvider(widget.slug));
    } on Object catch (e) {
      replace(p);
      if (mounted) showSnack(context, ErrorView.messageFor(l, e));
    } finally {
      _busy.remove(p.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    final me = ref.watch(sessionUserIdProvider);
    if (_people.isEmpty) {
      if (_error != null) return ErrorView(error: _error!, onRetry: () => _load(reset: true));
      if (_loading || !_done) return const LoadingView();
      return EmptyState(
        message: widget.following ? l.followingEmpty : l.followersEmpty,
        icon: Icons.people_outline,
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 400) unawaited(_load());
          return false;
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _people.length + (_done ? 0 : 1),
          separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, i) {
            if (i >= _people.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final p = _people[i];
            return ListTile(
              minTileHeight: 64,
              leading: Avatar.of(p),
              title: Text(p.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: p.headline.isEmpty
                  ? null
                  : Text(p.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => context.push('/perfil/${p.slug}'),
              trailing: p.userId == me
                  ? null
                  : FollowButton(
                      small: true,
                      following: p.isFollowing,
                      onPressed: () => _toggle(p),
                    ),
            );
          },
        ),
      ),
    );
  }
}
