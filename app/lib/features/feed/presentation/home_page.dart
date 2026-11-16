import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/feed/application/feed_controller.dart';
import 'package:icex_atlas/features/feed/presentation/composer.dart';
import 'package:icex_atlas/features/feed/presentation/post_actions.dart';
import 'package:icex_atlas/features/feed/presentation/post_card.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:icex_atlas/shared/widgets/follow_button.dart';

/// Inicio (feed): tarjeta de perfil, compositor, novedad destacada, publicaciones y widgets
/// (Orientador, La comunidad en cifras, Personas que quizá conozcas).
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final feed = ref.watch(feedControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final me = session is SignedIn ? session.me : null;
    final showDemo = ref.watch(appEnvProvider).showDemoBanner;

    return RefreshIndicator(
      color: IcexColors.primary,
      onRefresh: () => ref.refresh(feedControllerProvider.future),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 600) {
            ref.read(feedControllerProvider.notifier).loadMore().ignore();
          }
          return false;
        },
        child: CustomScrollView(
          slivers: [
            if (showDemo) const SliverToBoxAdapter(child: DemoBanner()),
            SliverToBoxAdapter(child: PageHeader(title: l.homeTitle)),
            if (me != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                sliver: SliverToBoxAdapter(child: MyProfileCard(me: me.profile.card)),
              ),
            if (me != null)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(child: Composer(me: me.profile.card)),
              ),
            ...switch (feed) {
              AsyncData(:final value) => [
                for (final d in value.destacadas)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: FeaturedNewsBanner(post: d, onTap: () => context.push(Routes.news)),
                    ),
                  ),
                if (value.posts.isEmpty)
                  SliverToBoxAdapter(
                    child: EmptyState(message: l.emptyFeed, icon: Icons.dynamic_feed_outlined),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  sliver: SliverList.separated(
                    itemCount: value.posts.length + (value.hasMore ? 1 : 0),
                    separatorBuilder: (_, i) =>
                        i == 2 ? const _SideWidgets() : const SizedBox(height: 12),
                    itemBuilder: (context, i) => i == value.posts.length
                        ? const Padding(padding: EdgeInsets.all(16), child: LoadingView())
                        : ConnectedPostCard(key: ValueKey(value.posts[i].id), post: value.posts[i]),
                  ),
                ),
              ],
              AsyncError(:final error) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(feedControllerProvider),
                  ),
                ),
              ],
              _ => [const SliverFillRemaining(hasScrollBody: false, child: LoadingView())],
            },
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de perfil propia con franja roja/amarilla (mockup).
class MyProfileCard extends StatelessWidget {
  const MyProfileCard({required this.me, super.key});

  final ProfileCard me;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: IcexColors.card,
        borderRadius: BorderRadius.circular(IcexTheme.radius),
        border: Border.all(color: IcexColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 92,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                const Positioned.fill(bottom: 36, child: IcexStripe(height: 56)),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => context.push(Routes.profile(me.slug)),
                  child: Avatar.of(me, size: 76, ring: true),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                Text(me.nombre, style: t.titleMedium, textAlign: TextAlign.center),
                if (me.headline.isNotEmpty)
                  Text(
                    me.headline,
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(color: IcexColors.mutedForeground),
                  ),
                const SizedBox(height: 8),
                PhasePromoRow(fase: me.fase, promocion: me.promocion),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: [
                _KV(l.followers, '${me.seguidoresCount}'),
                const SizedBox(height: 4),
                _KV(l.following, '${me.siguiendoCount}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KV extends StatelessWidget {
  const _KV(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        k,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: IcexColors.mutedForeground),
      ),
      const Spacer(),
      Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
    ],
  );
}

/// Widgets laterales del mockup, intercalados en el feed en móvil.
class _SideWidgets extends StatelessWidget {
  const _SideWidgets();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Column(
      children: [
        OrientadorTeaser(),
        SizedBox(height: 12),
        CommunityStatsCard(),
        SizedBox(height: 12),
        SuggestionsCard(),
      ],
    ),
  );
}

class OrientadorTeaser extends StatelessWidget {
  const OrientadorTeaser({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      color: IcexColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IcexTheme.radius),
        side: const BorderSide(color: IcexColors.primary),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(IcexTheme.radius),
        onTap: () => context.go(Routes.orientador),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.orientadorTeaserTitle,
                style: t.titleLarge?.copyWith(color: IcexColors.primary),
              ),
              const SizedBox(height: 4),
              Text(
                l.orientadorTeaserBody,
                style: t.bodyMedium?.copyWith(color: IcexColors.mutedForeground),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CommunityStatsCard extends ConsumerWidget {
  const CommunityStatsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final stats = ref.watch(communityStatsProvider).value;
    final t = Theme.of(context).textTheme;
    Widget tile(String n, String label) => Expanded(
      child: Semantics(
        label: '$n $label',
        excludeSemantics: true,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: IcexColors.muted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, style: t.headlineSmall?.copyWith(color: IcexColors.primary)),
              Text(label, style: t.bodySmall),
            ],
          ),
        ),
      ),
    );
    return IcexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(l.communityStatsTitle, style: t.titleMedium)),
          const SizedBox(height: 12),
          Row(
            children: [
              tile('${stats?.alumni ?? '–'}', l.statsAlumni),
              const SizedBox(width: 8),
              tile('${stats?.activos ?? '–'}', l.statsActive),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              tile('${stats?.paises ?? '–'}', l.statsCountries),
              const SizedBox(width: 8),
              tile('${stats?.promociones ?? '–'}', l.statsPromotions),
            ],
          ),
        ],
      ),
    );
  }
}

class SuggestionsCard extends ConsumerWidget {
  const SuggestionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final people = ref.watch(suggestionsProvider).value ?? const [];
    if (people.isEmpty) return const SizedBox.shrink();
    return IcexCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: Text(l.suggestionsTitle, style: t.titleMedium)),
          for (final p in people)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => context.push(Routes.profile(p.slug)),
                    child: Avatar.of(p, size: 48, ring: true),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nombre, style: t.titleSmall),
                        if (p.empresa != null) Text(p.empresa!, style: t.bodySmall),
                        const SizedBox(height: 4),
                        PhasePromoRow(fase: p.fase, promocion: p.promocion),
                        const SizedBox(height: 6),
                        FollowButton(
                          following: p.isFollowing,
                          small: true,
                          onPressed: p.isFollowing
                              ? null
                              : () => ref.read(suggestionsProvider.notifier).follow(p),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
