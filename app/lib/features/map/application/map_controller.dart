import 'dart:async';

import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/features/map/data/map_repository.dart';
import 'package:icex_atlas/features/map/domain/map_models.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'map_controller.g.dart';

class MapFilters {
  const MapFilters({
    this.fases = const {Fase.fase0, Fase.fase1, Fase.fase2, Fase.activo},
    this.showClubs = true,
  });

  final Set<Fase> fases;
  final bool showClubs;

  MapFilters toggle(Fase f) => MapFilters(
    fases: fases.contains(f) ? ({...fases}..remove(f)) : {...fases, f},
    showClubs: showClubs,
  );

  MapFilters withClubs({required bool value}) => MapFilters(fases: fases, showClubs: value);
}

class MapState {
  const MapState({required this.data, required this.filters, this.loading = false, this.error});

  final MapViewData data;
  final MapFilters filters;
  final bool loading;
  final Object? error;
}

@riverpod
class MapViewController extends _$MapViewController {
  Timer? _debounce;
  ({int zoom, Bounds bounds})? _view;
  int _gen = 0;

  @override
  MapState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const MapState(data: MapViewData.empty, filters: MapFilters(), loading: true);
  }

  /// La cámara cambió: recalcular clusters (con antirrebote, el cálculo es en SQL).
  void onCamera(int zoom, Bounds bounds) {
    _view = (zoom: zoom, bounds: bounds);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => unawaited(_load()));
  }

  void setFilters(MapFilters f) {
    state = MapState(data: state.data, filters: f, loading: true);
    unawaited(_load());
  }

  Future<void> _load() async {
    final v = _view;
    if (v == null) return;
    final gen = ++_gen;
    final f = state.filters;
    try {
      final data = await ref
          .read(mapRepositoryProvider)
          .clusters(zoom: v.zoom, bounds: v.bounds, fases: f.fases, includeClubs: f.showClubs);
      if (gen == _gen) state = MapState(data: data, filters: f);
    } on Object catch (e) {
      if (gen == _gen) state = MapState(data: state.data, filters: f, error: e);
    }
  }
}

@riverpod
Future<List<ProfileCard>> alumniNear(Ref ref, double lat, double lng) =>
    ref.watch(mapRepositoryProvider).alumniNear(lat, lng);

@riverpod
class ClubController extends _$ClubController {
  @override
  Future<Club> build(String id) => ref.watch(clubsRepositoryProvider).get(id);

  Future<void> toggleMembership() async {
    final c = state.value;
    if (c == null) return;
    final repo = ref.read(clubsRepositoryProvider);
    state = AsyncData(c.isMember ? await repo.leave(id) : await repo.join(id));
  }

  Future<void> toggleRegistration(ClubEvent e) async {
    final repo = ref.read(clubsRepositoryProvider);
    if (e.inscripcion == Inscripcion.ninguna) {
      await repo.register(e.id);
    } else {
      await repo.cancel(e.id);
    }
    state = AsyncData(await repo.get(id));
  }
}
