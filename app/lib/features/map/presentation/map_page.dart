import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/map/application/map_controller.dart';
import 'package:icex_atlas/features/map/data/map_repository.dart';
import 'package:icex_atlas/features/map/domain/map_models.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/avatar.dart';
import 'package:icex_atlas/shared/widgets/badges.dart';
import 'package:icex_atlas/shared/widgets/common.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mapa mundial con alumni y clubs agrupados por zoom (clusters con número calculados en SQL).
/// Teselas OpenStreetMap por defecto, configurables (MAP_TILE_URL / app_config).
class MapPage extends ConsumerStatefulWidget {
  const MapPage({super.key});

  @override
  ConsumerState<MapPage> createState() => _MapPageState();
}

class _MapPageState extends ConsumerState<MapPage> {
  final _map = MapController();

  void _onCamera(MapCamera c) {
    final b = c.visibleBounds;
    ref
        .read(mapViewControllerProvider.notifier)
        .onCamera(
          c.zoom.round(),
          Bounds(west: b.west, south: b.south, east: b.east, north: b.north),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final env = ref.watch(appEnvProvider);
    final s = ref.watch(mapViewControllerProvider);
    final maxCount = s.data.clusters.fold<int>(1, (m, c) => c.count > m ? c.count : m);

    return Column(
      children: [
        PageHeader(title: l.mapTitle, subtitle: l.mapSubtitle(s.data.total, s.data.clubs.length)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _showFilters(context),
              icon: const Icon(Icons.tune),
              label: Text(l.mapFilters),
            ),
          ),
        ),
        Expanded(
          child: Semantics(
            label: '${l.mapTitle}. ${l.mapSubtitle(s.data.total, s.data.clubs.length)}',
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: const LatLng(30, 5),
                initialZoom: 2,
                minZoom: 1,
                maxZoom: 14, // ubicación a nivel de ciudad: no tiene sentido acercar más
                onMapReady: () => _onCamera(_map.camera),
                onPositionChanged: (camera, _) => _onCamera(camera),
              ),
              children: [
                TileLayer(urlTemplate: env.mapTileUrl, userAgentPackageName: 'es.icexalumni.atlas'),
                MarkerLayer(
                  markers: [
                    for (final c in s.data.clusters)
                      Marker(
                        point: LatLng(c.lat, c.lng),
                        width: c.isSingle ? 40 : _size(c.count, maxCount),
                        height: c.isSingle ? 40 : _size(c.count, maxCount),
                        child: c.isSingle
                            ? GestureDetector(
                                onTap: () => context.push(Routes.profile(c.alumni!.slug)),
                                child: Avatar.of(c.alumni!, size: 40, ring: true),
                              )
                            : _ClusterBubble(count: c.count, onTap: () => _openCluster(context, c)),
                      ),
                    if (s.filters.showClubs)
                      for (final club in s.data.clubs)
                        Marker(
                          point: LatLng(club.lat, club.lng),
                          width: 36,
                          height: 36,
                          child: Semantics(
                            button: true,
                            label: club.nombre,
                            child: GestureDetector(
                              onTap: () => context.push(Routes.club(club.id)),
                              child: const DecoratedBox(
                                decoration: BoxDecoration(
                                  color: IcexColors.accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.flag, size: 20, color: IcexColors.onAccent),
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      env.mapTileAttribution,
                      onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static double _size(int n, int max) => 34 + 26 * (n / max).clamp(0, 1);

  Future<void> _openCluster(BuildContext context, MapCluster c) async {
    // Cluster grande y zoom bajo → acercar; si no, listar alumni de la zona.
    if (_map.camera.zoom < 9 && c.count > 8) {
      _map.move(LatLng(c.lat, c.lng), (_map.camera.zoom + 3).clamp(1, 14));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ClusterSheet(cluster: c),
    );
  }

  Future<void> _showFilters(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Consumer(
      builder: (context, ref, _) {
        final l = AppLocalizations.of(context);
        final f = ref.watch(mapViewControllerProvider).filters;
        final c = ref.read(mapViewControllerProvider.notifier);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(l.mapShowClubs),
                value: f.showClubs,
                onChanged: (v) => c.setFilters(f.withClubs(value: v)),
              ),
              ListTile(title: Text(l.mapPhases, style: Theme.of(context).textTheme.titleSmall)),
              for (final fase in Fase.values)
                CheckboxListTile(
                  title: Text(fase.label),
                  value: f.fases.contains(fase),
                  onChanged: (_) => c.setFilters(f.toggle(fase)),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: AppLocalizations.of(context).mapClusterTitle(count),
    excludeSemantics: true,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: IcexColors.primary.withValues(alpha: 0.9),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
        ),
        alignment: Alignment.center,
        child: FittedBox(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Text(
              '$count',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ClusterSheet extends ConsumerWidget {
  const _ClusterSheet({required this.cluster});

  final MapCluster cluster;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final people = ref.watch(alumniNearProvider(cluster.lat, cluster.lng));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      builder: (_, scroll) => Column(
        children: [
          Text(l.mapClusterTitle(cluster.count), style: Theme.of(context).textTheme.titleMedium),
          Expanded(
            child: people.when(
              data: (list) => ListView(
                controller: scroll,
                children: [
                  for (final p in list)
                    ListTile(
                      leading: Avatar.of(p, ring: true),
                      title: Text(p.nombre),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (p.headline.isNotEmpty) Text(p.headline),
                          const SizedBox(height: 4),
                          PhasePromoRow(fase: p.fase, promocion: p.promocion),
                        ],
                      ),
                      onTap: () => context.push(Routes.profile(p.slug)),
                    ),
                ],
              ),
              error: (e, _) => ErrorView(error: e),
              loading: LoadingView.new,
            ),
          ),
        ],
      ),
    );
  }
}
