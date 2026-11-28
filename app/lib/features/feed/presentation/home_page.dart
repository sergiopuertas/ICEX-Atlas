import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/feed/application/feed_controller.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/feed/presentation/composer.dart';
import 'package:icex_atlas/features/feed/presentation/post_actions.dart';
import 'package:icex_atlas/features/feed/presentation/post_card.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/features/profiles/domain/profile_completion.dart';
import 'package:icex_atlas/features/profiles/presentation/profile_completion_card.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/app_shell.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/brand.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:icex_atlas/shared/widgets/follow_button.dart';

/// Inicio (feed).
///
/// Disposición tipo LinkedIn: «Comparte una novedad» arriba, comunicado destacado y
/// publicaciones a todo el ancho separadas por una franja fina. Solo se intercala, una vez,
/// el carrusel de «Personas que quizá conozcas»: el feed tiene que leerse sin anuncios.
///
/// Arranque en frío (quien acaba de llegar no sigue a nadie): bajo un feed vacío o corto
/// aparece «Destacado en la comunidad» y, si al perfil le falta lo básico, el aviso de
/// completarlo (descartable).
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scroll = ScrollController();

  /// Las sugerencias de personas van tras la tercera publicación (una sola vez). El feed es
  /// para leer publicaciones: no se intercalan más bloques.
  static const _suggestionsAfter = 2;

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
    final completion = me == null ? null : ProfileCompletion.of(me.profile);
    final showCompletion =
        (completion?.worthNudgingOnHome ?? false) &&
        ref.watch(profileCompletionDismissedProvider).value == false;
    final cold = switch (feed) {
      AsyncValue(:final value?) => !value.hasMore && value.posts.length < coldFeedThreshold,
      _ => false,
    };
    final known = feed.value?.posts.map((p) => p.id).toSet() ?? const <String>{};
    final highlights = cold
        ? (ref.watch(communityHighlightsProvider).value ?? const <Post>[])
              .where((p) => !known.contains(p.id))
              .toList()
        : const <Post>[];

    Widget extrasAfter(int i) => i == _suggestionsAfter
        ? const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: SuggestionsCarousel())
        : const SizedBox(height: 8);

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
            if (me != null)
              SliverToBoxAdapter(
                child: HeroHeader(
                  title: l.homeGreeting(me.profile.card.nombre.split(' ').first),
                  subtitle: l.homeSubtitle,
                  bottom: Composer(me: me.profile.card, floating: true),
                ),
              ),
            if (showDemo) const SliverToBoxAdapter(child: DemoBanner()),
            if (showCompletion && completion != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: ProfileCompletionCard(completion: completion, dismissible: true),
                ),
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
                    child: highlights.isEmpty
                        ? EmptyState(
                            message: l.emptyFeed,
                            icon: Icons.dynamic_feed_outlined,
                            action: FilledButton.tonal(
                              onPressed: () =>
                                  StatefulNavigationShell.maybeOf(context)?.goBranch(1),
                              child: Text(l.exploreNetwork),
                            ),
                          )
                        : const _ColdStartIntro(),
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
                // Feed corto: las sugerencias van al final si no hay hueco entre publicaciones.
                if (value.posts.isNotEmpty &&
                    value.posts.length + (value.hasMore ? 1 : 0) - 1 <= _suggestionsAfter)
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    sliver: SliverToBoxAdapter(child: SuggestionsCarousel()),
                  ),
                if (highlights.isNotEmpty) ...[
                  const SliverToBoxAdapter(child: _HighlightsHeader()),
                  SliverList.separated(
                    itemCount: highlights.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => ConnectedPostCard(
                      key: ValueKey('hl-${highlights[i].id}'),
                      post: highlights[i],
                      flat: true,
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
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

/// Feed vacío pero con contenido de la comunidad: en vez de «no hay nada», qué hacer.
class _ColdStartIntro extends StatelessWidget {
  const _ColdStartIntro();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      key: const Key('cold-start-intro'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.coldStartTitle, style: t.titleMedium),
          const SizedBox(height: 4),
          Text(l.coldStartBody, style: t.bodyMedium?.copyWith(color: IcexColors.mutedForeground)),
        ],
      ),
    );
  }
}

class _HighlightsHeader extends StatelessWidget {
  const _HighlightsHeader();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      key: const Key('highlights-header'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_outlined, size: 20, color: IcexColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(l.highlightsTitle, style: t.titleSmall)),
                Text(l.highlightsSubtitle, style: t.bodySmall),
              ],
            ),
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
              // Crece con el tamaño de texto del sistema; antes, con 246 fijos, la tarjeta
              // se desbordaba («RenderFlex overflowed») en algunos móviles.
              height: 262 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.6),
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
                child: DecoratedBox(decoration: BoxDecoration(gradient: icexHeroGradient)),
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
