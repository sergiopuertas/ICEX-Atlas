import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/directory/application/directory_controller.dart';
import 'package:icex_atlas/features/directory/data/directory_repository.dart';
import 'package:icex_atlas/features/feed/application/feed_controller.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:icex_atlas/shared/widgets/follow_button.dart';

/// Red: directorio con buscador, filtro de promoción y fase, pestañas y Seguir.
class NetworkPage extends ConsumerWidget {
  const NetworkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final s = ref.watch(directoryControllerProvider);
    final c = ref.read(directoryControllerProvider.notifier);
    final stats = ref.watch(communityStatsProvider).value;
    final session = ref.watch(sessionControllerProvider);
    final myPromo = session is SignedIn ? session.me.profile.card.promocion : 0;
    final myId = session is SignedIn ? session.me.userId : null;

    final tabs = {
      DirectoryTab.todos: l.tabAll,
      DirectoryTab.miPromocion: l.tabMyPromo(myPromo),
      DirectoryTab.exterior: l.tabAbroad,
      DirectoryTab.activo: l.tabActive,
    };

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600) c.loadMore().ignore();
        return false;
      },
      child: CustomScrollView(
        slivers: [
          if (ref.watch(appEnvProvider).showDemoBanner)
            const SliverToBoxAdapter(child: DemoBanner()),
          SliverToBoxAdapter(
            child: PageHeader(
              title: l.networkTitle,
              subtitle: stats == null
                  ? null
                  : l.networkSubtitle(stats.alumni, stats.paises, stats.promociones),
            ),
          ),
          SliverToBoxAdapter(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Semantics(
                container: true,
                label: 'Grupos de alumni',
                child: Row(
                  children: [
                    for (final e in tabs.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: e.key == s.filter.tab
                            ? FilledButton(onPressed: () => c.setTab(e.key), child: Text(e.value))
                            : TextButton(onPressed: () => c.setTab(e.key), child: Text(e.value)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    key: const Key('directory-search'),
                    onChanged: c.setQuery,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: l.searchDirectoryHint,
                      labelText: l.searchDirectoryLabel,
                      floatingLabelBehavior: FloatingLabelBehavior.never,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    initialValue: s.filter.promocion,
                    isExpanded: true,
                    decoration: const InputDecoration(),
                    items: [
                      DropdownMenuItem(child: Text(l.allPromotions)),
                      for (var p = 51; p >= 1; p--)
                        DropdownMenuItem(value: p, child: Text(l.promotionLabel(p))),
                    ],
                    onChanged: c.setPromocion,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(l.allPhases),
                        selected: s.filter.fase == null,
                        onSelected: (_) => c.setFase(null),
                      ),
                      for (final f in Fase.values)
                        ChoiceChip(
                          label: Text(f.label),
                          selected: s.filter.fase == f,
                          onSelected: (_) => c.setFase(f),
                          labelStyle: TextStyle(
                            color: s.filter.fase == f ? Colors.white : IcexColors.foreground,
                          ),
                        ),
                    ],
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider()),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l.resultsCount(s.items.length, s.total),
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: IcexColors.mutedForeground),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (s.error != null && s.items.isEmpty)
            SliverToBoxAdapter(
              child: ErrorView(error: s.error!, onRetry: c.retry),
            )
          else if (!s.loading && s.items.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(message: l.noResults, icon: Icons.person_search_outlined),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.separated(
              itemCount: s.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => MemberCard(
                key: ValueKey(s.items[i].userId),
                profile: s.items[i],
                isMe: s.items[i].userId == myId,
                onFollow: () async {
                  try {
                    await c.toggleFollow(s.items[i]);
                  } on Object catch (e) {
                    if (context.mounted) showSnack(context, ErrorView.messageFor(l, e));
                  }
                },
              ),
            ),
          ),
          if (s.loading)
            const SliverToBoxAdapter(
              child: Padding(padding: EdgeInsets.all(16), child: LoadingView()),
            )
          else if (s.hasMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: OutlinedButton(onPressed: c.loadMore, child: Text(l.loadMore)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de miembro del directorio (mockup): cabecera gris, avatar con anillo, badges y ciudad.
class MemberCard extends StatelessWidget {
  const MemberCard({required this.profile, required this.onFollow, this.isMe = false, super.key});

  final ProfileCard profile;
  final VoidCallback onFollow;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = profile;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: IcexColors.card,
        borderRadius: BorderRadius.circular(IcexTheme.radius),
        border: Border.all(color: IcexColors.border),
      ),
      child: InkWell(
        onTap: () => context.push(Routes.profile(p.slug)),
        child: Column(
          children: [
            SizedBox(
              height: 100,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  const Positioned.fill(bottom: 44, child: ColoredBox(color: IcexColors.muted)),
                  Avatar.of(p, size: 88, ring: true),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  Text(p.nombre, style: t.titleMedium, textAlign: TextAlign.center),
                  if (p.headline.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        p.headline,
                        textAlign: TextAlign.center,
                        style: t.bodyMedium?.copyWith(color: IcexColors.mutedForeground),
                      ),
                    ),
                  const SizedBox(height: 10),
                  PhasePromoRow(fase: p.fase, promocion: p.promocion),
                  if (p.location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(p.location, style: t.bodySmall),
                  ],
                  if (!isMe) ...[
                    const SizedBox(height: 10),
                    FollowButton(following: p.isFollowing, onPressed: onFollow, small: true),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
