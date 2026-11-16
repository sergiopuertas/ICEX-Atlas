import 'dart:async';

import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/features/directory/data/directory_repository.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'directory_controller.g.dart';

class DirectoryState {
  const DirectoryState({
    required this.filter,
    this.items = const [],
    this.total = 0,
    this.nextCursor,
    this.loading = false,
    this.error,
  });

  final DirectoryFilter filter;
  final List<ProfileCard> items;
  final int total;
  final String? nextCursor;
  final bool loading;
  final Object? error;

  bool get hasMore => nextCursor != null;

  DirectoryState copyWith({
    DirectoryFilter? filter,
    List<ProfileCard>? items,
    int? total,
    String? Function()? nextCursor,
    bool? loading,
    Object? Function()? error,
  }) => DirectoryState(
    filter: filter ?? this.filter,
    items: items ?? this.items,
    total: total ?? this.total,
    nextCursor: nextCursor == null ? this.nextCursor : nextCursor(),
    loading: loading ?? this.loading,
    error: error == null ? this.error : error(),
  );
}

@riverpod
class DirectoryController extends _$DirectoryController {
  Timer? _debounce;
  int _generation = 0;

  @override
  DirectoryState build() {
    ref.onDispose(() => _debounce?.cancel());
    unawaited(Future.microtask(_load));
    return const DirectoryState(filter: DirectoryFilter(), loading: true);
  }

  /// Búsqueda con antirrebote (300 ms) para no lanzar una consulta por tecla.
  void setQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => setFilter(state.filter.copyWith(query: q)),
    );
  }

  void setTab(DirectoryTab tab) => setFilter(state.filter.withTab(tab));

  void setPromocion(int? promo) => setFilter(state.filter.copyWith(promocion: () => promo));

  void setFase(Fase? fase) => setFilter(state.filter.copyWith(fase: () => fase));

  void setFilter(DirectoryFilter f) {
    if (f == state.filter && state.error == null) return;
    state = DirectoryState(filter: f, loading: true);
    unawaited(_load());
  }

  Future<void> retry() => _load();

  Future<void> _load() async {
    final gen = ++_generation;
    final filter = state.filter;
    state = state.copyWith(loading: true, error: () => null);
    try {
      final page = await ref.read(directoryRepositoryProvider).search(filter);
      if (gen != _generation) return; // respuesta obsoleta
      state = state.copyWith(
        items: page.items,
        total: page.total ?? page.items.length,
        nextCursor: () => page.nextCursor,
        loading: false,
      );
    } on Object catch (e) {
      if (gen == _generation) state = state.copyWith(loading: false, error: () => e);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.loading) return;
    final gen = _generation;
    state = state.copyWith(loading: true);
    try {
      final page = await ref
          .read(directoryRepositoryProvider)
          .search(state.filter, cursor: state.nextCursor);
      if (gen != _generation) return;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        nextCursor: () => page.nextCursor,
        loading: false,
      );
    } on Object catch (e) {
      state = state.copyWith(loading: false, error: () => e);
    }
  }

  /// Seguir / dejar de seguir con actualización optimista.
  Future<void> toggleFollow(ProfileCard p) async {
    final next = !p.isFollowing;
    _replace(p.copyWith(isFollowing: next));
    try {
      final social = ref.read(socialRepositoryProvider);
      final r = next ? await social.follow(p.userId) : await social.unfollow(p.userId);
      _replace(p.copyWith(isFollowing: r.isFollowing, seguidoresCount: r.seguidoresCount));
    } on Object {
      _replace(p);
      rethrow;
    }
  }

  void _replace(ProfileCard p) => state = state.copyWith(
    items: [
      for (final x in state.items)
        if (x.userId == p.userId) p else x,
    ],
  );
}
