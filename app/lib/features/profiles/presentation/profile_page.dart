import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/feed/presentation/post_actions.dart';
import 'package:icex_atlas/features/profiles/application/profile_controller.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/features/social/data/social_repository.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/brand.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:icex_atlas/shared/widgets/expandable_text.dart';
import 'package:icex_atlas/shared/widgets/follow_button.dart';
import 'package:intl/intl.dart';

/// Perfil propio y ajeno, con la estructura de LinkedIn: portada, avatar superpuesto,
/// titular, cifras, acciones principales lado a lado, «Acerca de», trayectoria en línea de
/// tiempo y publicaciones.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final profile = ref.watch(profileControllerProvider(slug));
    final value = profile.value;
    return Scaffold(
      appBar: AppBar(
        title: Text(value?.card.nombre ?? ''),
        actions: [
          if (value?.isSelf ?? false)
            IconButton(
              tooltip: l.navSettings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(Routes.settings),
            )
          else if (value != null)
            PopupMenuButton<String>(
              tooltip: l.moreOptions,
              onSelected: (v) => switch (v) {
                'report' => showReportSheet(context, ref, ReportTarget.perfil, value.card.userId),
                _ => _confirmBlock(context, ref, value),
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    leading: const Icon(Icons.flag_outlined),
                    title: Text(l.report),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: ListTile(
                    leading: const Icon(Icons.block, color: IcexColors.destructive),
                    title: Text(l.profileBlock),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: switch (profile) {
        AsyncValue(:final value?) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(userPostsProvider(value.card.userId));
            final _ = await ref.refresh(profileControllerProvider(slug).future);
          },
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _Header(p: value, slug: slug),
              if ((value.bio ?? '').isNotEmpty)
                _Section(
                  title: l.profileAbout,
                  child: ExpandableText(value.bio!, style: t.bodyLarge, trimLines: 4),
                ),
              if (value.experiences.isNotEmpty)
                _Section(
                  title: l.profileTrajectory,
                  child: Column(
                    children: [
                      for (final (i, e) in value.experiences.indexed)
                        _ExperienceTile(e, last: i == value.experiences.length - 1),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Semantics(header: true, child: Text(l.profilePosts, style: t.titleMedium)),
              ),
              ref
                  .watch(userPostsProvider(value.card.userId))
                  .when(
                    data: (posts) => posts.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(l.profileNoPosts, style: t.bodyMedium),
                          )
                        : PostList(posts: posts),
                    error: (e, _) => ErrorView(
                      error: e,
                      onRetry: () => ref.invalidate(userPostsProvider(value.card.userId)),
                    ),
                    loading: () => const PostSkeleton(),
                  ),
            ],
          ),
        ),
        AsyncValue(:final error?) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(profileControllerProvider(slug)),
        ),
        _ => const LoadingView(),
      },
    );
  }

  Future<void> _confirmBlock(BuildContext context, WidgetRef ref, ProfileDetail p) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l.profileBlock),
        content: Text(l.profileBlockConfirm(p.card.nombre)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: IcexColors.destructive),
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.profileBlock),
          ),
        ],
      ),
    );
    if (!(ok ?? false) || !context.mounted) return;
    try {
      await ref.read(profileControllerProvider(slug).notifier).block();
      if (!context.mounted) return;
      showSnack(context, l.profileBlocked(p.card.nombre));
      context.canPop() ? context.pop() : context.go(Routes.home);
    } on Object catch (e) {
      if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
    }
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.p, required this.slug});

  final ProfileDetail p;
  final String slug;

  static const _cover = 96.0;
  static const _avatar = 100.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = p.card;
    Widget stat(int n, String label) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: compactNumber(n),
            style: const TextStyle(fontWeight: FontWeight.w700, color: IcexColors.foreground),
          ),
          TextSpan(text: ' $label'),
        ],
      ),
      style: t.bodyMedium?.copyWith(color: IcexColors.mutedForeground),
    );

    return Material(
      color: IcexColors.card,
      shape: const Border(bottom: BorderSide(color: IcexColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _cover + _avatar / 2,
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: _cover,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: icexHeroGradient),
                    child: ExcludeSemantics(child: CustomPaint(painter: GlobePainter.header())),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: IcexColors.card, shape: BoxShape.circle),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Avatar.of(c, size: _avatar, ring: true),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(c.nombre, style: t.headlineSmall)),
                if (c.headline.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(c.headline, style: t.bodyLarge),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PhaseBadge(c.fase),
                    PromoBadge(c.promocion),
                    if (p.followsMe && !p.isSelf)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                        decoration: BoxDecoration(
                          color: IcexColors.muted,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(l.followsYou, style: t.bodySmall?.copyWith(fontSize: 11)),
                      ),
                  ],
                ),
                if (c.location.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: IcexColors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          c.location,
                          style: t.bodyMedium?.copyWith(color: IcexColors.mutedForeground),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    stat(c.seguidoresCount, l.followers.toLowerCase()),
                    stat(c.siguiendoCount, l.following.toLowerCase()),
                    if (p.postsCount > 0) stat(p.postsCount, l.postsLabel),
                  ],
                ),
                const SizedBox(height: 14),
                if (p.isSelf)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push(Routes.editProfile),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l.profileEdit),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FollowButton(
                          following: c.isFollowing,
                          onPressed: () async {
                            try {
                              await ref
                                  .read(profileControllerProvider(slug).notifier)
                                  .toggleFollow();
                            } on Object catch (e) {
                              if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => context.push(Routes.chatWith(c.userId)),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                          icon: const Icon(Icons.send_outlined, size: 18),
                          label: Text(l.profileSendMessage, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Material(
      color: IcexColors.card,
      shape: const Border.symmetric(horizontal: BorderSide(color: IcexColors.border)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text(title, style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    ),
  );
}

/// Experiencia en línea de tiempo (icono + línea vertical que une los puestos).
class _ExperienceTile extends StatelessWidget {
  const _ExperienceTile(this.e, {required this.last});

  final Experience e;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final f = DateFormat('MMM y', 'es');
    final t = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: e.isCurrent
                      ? IcexColors.primary.withValues(alpha: 0.08)
                      : IcexColors.muted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.business_center_outlined,
                  size: 20,
                  color: e.isCurrent ? IcexColors.primary : IcexColors.mutedForeground,
                ),
              ),
              if (!last)
                const Expanded(
                  child: VerticalDivider(width: 40, thickness: 1, color: IcexColors.border),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.cargo, style: t.titleSmall),
                  Text(e.empresa, style: t.bodyMedium),
                  Text(
                    '${f.format(e.desde)} – ${e.hasta == null ? l.profileCurrent : f.format(e.hasta!)}',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
