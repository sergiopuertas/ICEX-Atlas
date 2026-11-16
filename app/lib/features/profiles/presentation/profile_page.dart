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
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:icex_atlas/shared/widgets/follow_button.dart';
import 'package:intl/intl.dart';

/// Perfil propio y ajeno: cabecera, seguir, enviar mensaje, trayectoria y publicaciones.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({required this.slug, super.key});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final profile = ref.watch(profileControllerProvider(slug));
    return Scaffold(
      appBar: AppBar(
        title: Text(profile.value?.card.nombre ?? ''),
        actions: [
          if (profile.value?.isSelf ?? false)
            IconButton(
              tooltip: l.navSettings,
              icon: const Icon(Icons.settings_outlined),
              onPressed: () => context.push(Routes.settings),
            )
          else if (profile.value != null)
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'report' => showReportSheet(
                  context,
                  ref,
                  ReportTarget.perfil,
                  profile.value!.card.userId,
                ),
                _ => _confirmBlock(context, ref, profile.value!),
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'report', child: Text(l.report)),
                PopupMenuItem(value: 'block', child: Text(l.profileBlock)),
              ],
            ),
        ],
      ),
      body: switch (profile) {
        AsyncData(:final value) => RefreshIndicator(
          onRefresh: () => ref.refresh(profileControllerProvider(slug).future),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Header(p: value, slug: slug),
              if ((value.bio ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _Section(
                  title: l.profileAbout,
                  child: Text(value.bio!, style: Theme.of(context).textTheme.bodyLarge),
                ),
              ],
              if (value.experiences.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Section(
                  title: l.profileTrajectory,
                  child: Column(children: [for (final e in value.experiences) _ExperienceTile(e)]),
                ),
              ],
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(l.profilePosts, style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 8),
              ref
                  .watch(userPostsProvider(value.card.userId))
                  .when(
                    data: (posts) => PostList(posts: posts),
                    error: (e, _) => ErrorView(error: e),
                    loading: LoadingView.new,
                  ),
            ],
          ),
        ),
        AsyncError(:final error) => ErrorView(error: error),
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
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.profileBlock)),
        ],
      ),
    );
    if ((ok ?? false) && context.mounted) {
      await ref.read(profileControllerProvider(slug).notifier).block();
      if (context.mounted) context.pop();
    }
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.p, required this.slug});

  final ProfileDetail p;
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final c = p.card;
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
            height: 116,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                const Positioned.fill(bottom: 48, child: IcexStripe(height: 68)),
                Avatar.of(c, size: 96, ring: true),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              children: [
                Semantics(
                  header: true,
                  child: Text(c.nombre, style: t.headlineSmall, textAlign: TextAlign.center),
                ),
                if (c.headline.isNotEmpty)
                  Text(
                    c.headline,
                    textAlign: TextAlign.center,
                    style: t.bodyLarge?.copyWith(color: IcexColors.mutedForeground),
                  ),
                const SizedBox(height: 8),
                PhasePromoRow(fase: c.fase, promocion: c.promocion),
                if (c.location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(c.location, style: t.bodySmall),
                ],
                const SizedBox(height: 12),
                Text(
                  '${c.seguidoresCount} ${l.followers.toLowerCase()} · ${c.siguiendoCount} ${l.following.toLowerCase()}',
                  style: t.bodyMedium,
                ),
                const SizedBox(height: 12),
                if (p.isSelf)
                  OutlinedButton.icon(
                    onPressed: () => context.push(Routes.editProfile),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l.profileEdit),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FollowButton(
                        following: c.isFollowing,
                        onPressed: () async {
                          try {
                            await ref.read(profileControllerProvider(slug).notifier).toggleFollow();
                          } on Object catch (e) {
                            if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
                          }
                        },
                      ),
                      OutlinedButton.icon(
                        onPressed: () => context.push(Routes.chatWith(c.userId)),
                        icon: const Icon(Icons.send_outlined, size: 18),
                        label: Text(l.profileSendMessage),
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
  Widget build(BuildContext context) => IcexCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _ExperienceTile extends StatelessWidget {
  const _ExperienceTile(this.e);

  final Experience e;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final f = DateFormat('MMM y', 'es');
    final t = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(
        backgroundColor: IcexColors.muted,
        child: Icon(Icons.business_center_outlined, color: IcexColors.mutedForeground),
      ),
      title: Text(e.cargo, style: t.titleSmall),
      subtitle: Text(
        '${e.empresa}\n${f.format(e.desde)} – ${e.hasta == null ? l.profileCurrent : f.format(e.hasta!)}',
      ),
      isThreeLine: true,
    );
  }
}
