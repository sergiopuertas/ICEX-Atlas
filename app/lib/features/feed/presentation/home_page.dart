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
import 'package:icex_atlas/shared/widgets/app_shell.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:icex_atlas/shared/widgets/follow_button.dart';

/// Inicio (feed).
///
/// Disposición tipo LinkedIn: «Comparte una novedad» arriba, comunicado destacado y
/// publicaciones a todo el ancho separadas por una franja fina. Los widgets del mockup
/// (Personas que quizá conozcas, Orientador, La comunidad en cifras) se intercalan entre
/// publicaciones; las sugerencias, como carrusel horizontal (Instagram).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  /// Posiciones (índice de publicación tras el que van) de los bloques intercalados.
  static const _suggestionsAfter = 1;
  static const _widgetsAfter = 4;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    listenScrollToTop(ref, AppTab.home, _scroll);
    final l = AppLocalizations.of(context);
    final feed = ref.watch(feedControllerProvider);
    final session = ref.watch(sessionControllerProvider);
    final me = session is SignedIn ? session.me : null;
    final showDemo = ref.watch(appEnvProvider).showDemoBanner;

    const widgetsBlock = [
      Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: OrientadorTeaser()),
      Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: CommunityStatsCard()),
    ];
    Widget block(List<Widget> children) => children.isEmpty
        ? const SizedBox(height: 8)
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(children: children),
          );
    Widget extrasAfter(int i) => block([
      if (i == _suggestionsAfter) const SuggestionsCarousel(),
      if (i == _widgetsAfter) ...widgetsBlock,
    ]);

    return RefreshIndicator(
      color: IcexColors.primary,
      onRefresh: () => ref.read(feedControllerProvider.notifier).refresh(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.extentAfter < 800) {
            ref.read(feedControllerProvider.notifier).loadMore().ignore();
          }
          return false;
        },
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (showDemo) const SliverToBoxAdapter(child: DemoBanner()),
            if (me != null)
              SliverPadding(
                padding: const EdgeInsets.only(top: 8),
                sliver: SliverToBoxAdapter(child: Composer(me: me.profile.card)),
              ),
            ...switch (feed) {
              AsyncValue(:final value?) => [
                for (final d in value.destacadas)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    sliver: SliverToBoxAdapter(
                      child: FeaturedNewsBanner(post: d, onTap: () => context.push(Routes.news)),
                    ),
                  ),
                if (value.posts.isEmpty) ...[
                  SliverToBoxAdapter(
                    child: EmptyState(
                      message: l.emptyFeed,
                      icon: Icons.dynamic_feed_outlined,
                      action: FilledButton.tonal(
                        onPressed: () => StatefulNavigationShell.maybeOf(context)?.goBranch(1),
                        child: Text(l.exploreNetwork),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SuggestionsCarousel()),
                ],
                SliverPadding(
                  padding: const EdgeInsets.only(top: 8),
                  sliver: SliverList.separated(
                    itemCount: value.posts.length + (value.hasMore ? 1 : 0),
                    separatorBuilder: (_, i) => extrasAfter(i),
                    itemBuilder: (context, i) => i == value.posts.length
                        ? const Padding(padding: EdgeInsets.all(24), child: LoadingView())
                        : ConnectedPostCard(
                            key: ValueKey(value.posts[i].id),
                            post: value.posts[i],
                            flat: true,
                          ),
                  ),
                ),
                // Feed corto: los bloques cuyo hueco no existe van al final.
                if (value.posts.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 16),
                    sliver: SliverToBoxAdapter(
                      child: Builder(
                        builder: (_) {
                          final separators = value.posts.length + (value.hasMore ? 1 : 0) - 1;
                          return block([
                            if (separators <= _suggestionsAfter) const SuggestionsCarousel(),
                            if (separators <= _widgetsAfter) ...widgetsBlock,
                          ]);
                        },
                      ),
                    ),
                  ),
              ],
              AsyncValue(:final error?) => [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorView(
                    error: error,
                    onRetry: () => ref.invalidate(feedControllerProvider),
                  ),
                ),
              ],
              _ => [
                SliverList.list(
                  children: const [
                    SizedBox(height: 8),
                    PostSkeleton(),
                    SizedBox(height: 8),
                    PostSkeleton(),
                  ],
                ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

class OrientadorTeaser extends StatelessWidget {
  const OrientadorTeaser({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(IcexTheme.radius)),
      child: Ink(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFC50516), Color(0xFF8E0410)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: () => StatefulNavigationShell.maybeOf(context)?.goBranch(AppTab.orientador.index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.explore_rounded, color: IcexColors.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.orientadorTeaserTitle,
                        style: t.titleMedium?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.orientadorTeaserBody,
                        style: t.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
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
    Widget tile(int? n, String label) => Expanded(
      child: Semantics(
        label: '${n ?? '–'} $label',
        excludeSemantics: true,
        child: Column(
          children: [
            Text(
              n == null ? '–' : compactNumber(n),
              style: t.titleLarge?.copyWith(color: IcexColors.primary),
            ),
            const SizedBox(height: 2),
            Text(label, style: t.bodySmall, textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
    return IcexCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Semantics(header: true, child: Text(l.communityStatsTitle, style: t.titleSmall)),
          ),
          Row(
            children: [
              tile(stats?.alumni, l.statsAlumni),
              tile(stats?.activos, l.statsActive),
              tile(stats?.paises, l.statsCountries),
              tile(stats?.promociones, l.statsPromotions),
            ],
          ),
        ],
      ),
    );
  }
}

/// «Personas que quizá conozcas» como carrusel horizontal (Instagram / LinkedIn):
/// ocupa poco alto, se descartan con la X y Seguir no saca de la pantalla.
class SuggestionsCarousel extends ConsumerWidget {
  const SuggestionsCarousel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final people = ref.watch(suggestionsProvider).value ?? const [];
    if (people.isEmpty) return const SizedBox.shrink();
    return Material(
      color: IcexColors.card,
      shape: const Border.symmetric(horizontal: BorderSide(color: IcexColors.border)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(l.suggestionsTitle, style: t.titleSmall),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        StatefulNavigationShell.maybeOf(context)?.goBranch(AppTab.network.index),
                    child: Text(l.seeAll),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 246,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: people.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => SuggestionCard(person: people[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SuggestionCard extends ConsumerWidget {
  const SuggestionCard({required this.person, super.key});

  final ProfileCard person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final p = person;
    final notifier = ref.read(suggestionsProvider.notifier);
    return SizedBox(
      width: 160,
      child: Material(
        color: IcexColors.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IcexTheme.radius),
          side: const BorderSide(color: IcexColors.border),
        ),
        child: InkWell(
          onTap: () => context.push(Routes.profile(p.slug)),
          child: Stack(
            children: [
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 44,
                child: IcexStripe(height: 44),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
                child: Column(
                  children: [
                    Avatar.of(p, size: 68, ring: true),
                    const SizedBox(height: 8),
                    Text(
                      p.nombre,
                      style: t.titleSmall?.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      p.headline,
                      style: t.bodySmall,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    PromoBadge(p.promocion, compact: true),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FollowButton(
                        following: p.isFollowing,
                        small: true,
                        onPressed: () async {
                          try {
                            await notifier.toggleFollow(p);
                          } on Object catch (e) {
                            if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  tooltip: l.dismiss,
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black26,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(28, 28),
                  ),
                  iconSize: 16,
                  onPressed: () => notifier.dismiss(p),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
