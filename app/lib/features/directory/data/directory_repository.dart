import 'package:flutter/foundation.dart' show immutable;
import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/core/api/page.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';

/// Pestañas del directorio (mockup): Todos / Mi promoción / En el exterior / ACTIVO.
enum DirectoryTab {
  todos('todos'),
  miPromocion('mi_promocion'),
  exterior('exterior'),
  activo('activo');

  const DirectoryTab(this.code);

  final String code;
}

@immutable
class DirectoryFilter {
  const DirectoryFilter({
    this.query = '',
    this.promocion,
    this.fase,
    this.tab = DirectoryTab.todos,
  });

  final String query;
  final int? promocion;
  final Fase? fase;
  final DirectoryTab tab;

  DirectoryFilter copyWith({
    String? query,
    int? Function()? promocion,
    Fase? Function()? fase,
    DirectoryTab? tab,
  }) => DirectoryFilter(
    query: query ?? this.query,
    promocion: promocion == null ? this.promocion : promocion(),
    fase: fase == null ? this.fase : fase(),
    tab: tab ?? this.tab,
  );

  /// Al cambiar de pestaña se limpian los filtros (como en el mockup).
  DirectoryFilter withTab(DirectoryTab t) => DirectoryFilter(query: query, tab: t);

  Map<String, dynamic> toParams() => {
    'p_query': query.trim().isEmpty ? null : query.trim(),
    'p_promocion': promocion,
    'p_fase': fase?.code,
    'p_tab': tab.code,
  };

  @override
  bool operator ==(Object other) =>
      other is DirectoryFilter &&
      other.query == query &&
      other.promocion == promocion &&
      other.fase == fase &&
      other.tab == tab;

  @override
  int get hashCode => Object.hash(query, promocion, fase, tab);
}

class DirectoryRepository {
  const DirectoryRepository(this._api);

  final ApiClient _api;

  static const pageSize = 24;

  Future<CursorPage<ProfileCard>> search(DirectoryFilter filter, {String? cursor}) async =>
      CursorPage.fromJson(
        await _api.rpcJson('search_directory', {
          ...filter.toParams(),
          'p_cursor': cursor,
          'p_limit': pageSize,
        }),
        ProfileCard.fromJson,
      );
}
