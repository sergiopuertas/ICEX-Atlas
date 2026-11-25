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
import 'package:icex_atlas/shared/widgets/app_shell.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/brand.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:icex_atlas/shared/widgets/follow_button.dart';

/// Red: directorio con buscador, pestañas, filtros de promoción y fase y Seguir.
///
/// El buscador va primero (es lo que más se usa), las pestañas como chips y los filtros
/// secundarios en una hoja inferior con contador de filtros activos. Resultados en
/// cuadrícula de dos columnas (como «Mi red» de LinkedIn): el doble de personas por pantalla.
class NetworkPage extends ConsumerStatefulWidget {
  const NetworkPage({super.key});

  @override
  ConsumerState<NetworkPage> createState() => _NetworkPageState();
}

class _NetworkPageState extends ConsumerState<NetworkPage> {
  final _scroll = ScrollController();
  final _search = TextEditingController();

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openFilters() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (_) => const _FiltersSheet(),
  );

  @override
  Widget build(BuildContext context) {
    listenScrollToTop(ref, AppTab.network, _scroll);
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final s = ref.watch(directoryControllerProvider);
    final c = ref.read(directoryControllerProvider.notifier);
    final stats = ref.watch(communityStatsProvider).value;
    final session = ref.watch(sessionControllerProvider);
    final myPromo = session is SignedIn ? session.me.profile.card.promocion : 0;
    final myId = session is SignedIn ? session.me.userId : null;
    final activeFilters = (s.filter.fase == null ? 0 : 1) + (s.filter.promocion == null ? 0 : 1);

    final tabs = {
      DirectoryTab.todos: l.tabAll,
      if (myPromo > 0) DirectoryTab.miPromocion: l.tabMyPromo(myPromo),
      DirectoryTab.exterior: l.tabAbroad,
      DirectoryTab.activo: l.tabActive,
    };

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.extentAfter < 600 && s.error == null) c.loadMore().ignore();
        return false;
      },
      child: RefreshIndicator(
        onRefresh: c.retry,
        child: CustomScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: HeroHeader(
                title: l.networkTitle,
                subtitle: stats == null
                    ? null
                    : l.networkSubtitle(stats.alumni, stats.paises, stats.promociones),
                bottom: Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _search,
                        builder: (_, v, _) => TextField(
                          key: const Key('directory-search'),
                          controller: _search,
                          onChanged: c.setQuery,
                          textInputAction: TextInputAction.search,
                          onTapOutside: (_) => FocusScope.of(context).unfocus(),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: v.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: l.clearSearch,
                                    icon: const Icon(Icons.close),
                                    onPressed: () {
                                      _search.clear();
                                      c.setQuery('');
                                    },
                                  ),
                            hintText: l.searchDirectoryHint,
                            labelText: l.searchDirectoryLabel,
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            fillColor: Colors.white,
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(999)),
                              borderSide: BorderSide.none,
                            ),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(999)),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(999)),
                              borderSide: BorderSide(color: IcexColors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: activeFilters > 0,
                      label: Text('$activeFilters'),
                      backgroundColor: IcexColors.accent,
                      textColor: IcexColors.onAccent,
                      child: IconButton.filled(
                        tooltip: l.filters,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: IcexColors.primary,
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: _openFilters,
                        icon: const Icon(Icons.tune),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (ref.watch(appEnvProvider).showDemoBanner)
              const SliverToBoxAdapter(child: DemoBanner()),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: Semantics(
                  container: true,
                  label: l.directoryGroups,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final e in tabs.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.value),
                            selected: e.key == s.filter.tab,
                            onSelected: (_) => c.setTab(e.key),
                            labelStyle: TextStyle(
                              color: e.key == s.filter.tab ? Colors.white : IcexColors.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              sliver: SliverToBoxAdapter(
                child: Semantics(
                  liveRegion: true,
                  child: Text(l.resultsCount(s.items.length, s.total), style: t.bodySmall),
                ),
              ),
            ),
            if (s.error != null && s.items.isEmpty)
              SliverToBoxAdapter(
                child: ErrorView(error: s.error!, onRetry: c.retry),
              )
            else if (!s.loading && s.items.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  message: l.noResults,
                  icon: Icons.person_search_outlined,
                  action: activeFilters > 0 || s.filter.query.isNotEmpty
                      ? OutlinedButton(
                          onPressed: () {
                            _search.clear();
                            c.setFilter(DirectoryFilter(tab: s.filter.tab));
                          },
                          child: Text(l.clearFilters),
                        )
                      : null,
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              sliver: SliverLayoutBuilder(
                builder: (context, constraints) => SliverGrid.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 240,
                    mainAxisExtent: memberCardHeight(context, constraints.crossAxisExtent),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: s.items.length,
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
      ),
    );
  }
}

/// Filtros secundarios (promoción y fase). Lee y escribe directamente el controlador.
class _FiltersSheet extends ConsumerWidget {
  const _FiltersSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;
    final f = ref.watch(directoryControllerProvider.select((s) => s.filter));
    final c = ref.read(directoryControllerProvider.notifier);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(l.filters, style: t.titleLarge)),
                TextButton(
                  onPressed: f.fase == null && f.promocion == null
                      ? null
                      : () => c.setFilter(f.copyWith(fase: () => null, promocion: () => null)),
                  child: Text(l.clearFilters),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l.fieldPhase, style: t.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l.allPhases),
                  selected: f.fase == null,
                  onSelected: (_) => c.setFase(null),
                  labelStyle: TextStyle(
                    color: f.fase == null ? Colors.white : IcexColors.foreground,
                  ),
                ),
                for (final fase in Fase.values)
                  ChoiceChip(
                    label: Text(fase.label),
                    selected: f.fase == fase,
                    onSelected: (_) => c.setFase(fase),
                    labelStyle: TextStyle(
                      color: f.fase == fase ? Colors.white : IcexColors.foreground,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(l.statsPromotions, style: t.titleSmall),
            const SizedBox(height: 8),
            // La clave fuerza a recrearlo cuando el filtro cambia desde fuera (p. ej. al
            // cambiar de pestaña o limpiar filtros): `initialValue` solo se lee al crearlo.
            DropdownButtonFormField<int?>(
              key: ValueKey(f.promocion),
              initialValue: f.promocion,
              isExpanded: true,
              menuMaxHeight: 360,
              items: [
                DropdownMenuItem(child: Text(l.allPromotions)),
                for (
                  var p = currentPromocion(
                    fromServer: ref.watch(communityStatsProvider).value?.promocionActual,
                  );
                  p >= 1;
                  p--
                )
                  DropdownMenuItem(value: p, child: Text(l.promotionLabel(p))),
              ],
              onChanged: c.setPromocion,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.showResults)),
          ],
        ),
      ),
    );
  }
}

/// Alto de [MemberCard]: crece con el tamaño de texto del sistema y en tarjetas estrechas
/// (móviles de 320 pt, donde nombre y cargo ocupan más líneas). Sin esto, la tarjeta se
/// desbordaba por abajo.
double memberCardHeight(BuildContext context, double availableWidth) {
  final width = availableWidth;
  final columns = (width / 250).ceil().clamp(1, 8);
  final cardWidth = (width - 10 * (columns - 1)) / columns;
  final narrow = cardWidth < 160 ? 28.0 : 0.0;
  return (268 + narrow) * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2.5);
}

/// Tarjeta de miembro: portada con los colores ICEX, avatar con anillo de fase, nombre,
/// titular, promoción y Seguir.
class MemberCard extends StatelessWidget {
  const MemberCard({required this.profile, required this.onFollow, this.isMe = false, super.key});

  final ProfileCard profile;
  final VoidCallback onFollow;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = profile;
    return Material(
      color: IcexColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(IcexTheme.radius),
        side: const BorderSide(color: IcexColors.border),
      ),
      child: InkWell(
        onTap: () => context.push(Routes.profile(p.slug)),
        child: Column(
          children: [
            SizedBox(
              height: 84,
              width: double.infinity,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 44,
                    child: DecoratedBox(decoration: BoxDecoration(gradient: icexHeroGradient)),
                  ),
                  Avatar.of(p, size: 72, ring: true),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                child: Column(
                  children: [
                    Text(
                      p.nombre,
                      style: t.titleSmall?.copyWith(fontSize: 14),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (p.headline.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          p.headline,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodySmall,
                        ),
                      ),
                    const Spacer(),
                    PhasePromoRow(
                      fase: p.fase,
                      promocion: p.promocion,
                      compact: true,
                      alignment: WrapAlignment.center,
                    ),
                    if (p.location.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          p.location,
                          style: t.bodySmall?.copyWith(fontSize: 11.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (!isMe) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FollowButton(
                          following: p.isFollowing,
                          onPressed: onFollow,
                          small: true,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
