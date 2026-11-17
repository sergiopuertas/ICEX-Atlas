import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Acceso del panel a la API (`api.admin_*`). Todas las funciones comprueban el rol en
/// la base de datos: aunque alguien manipule el cliente, sin rol admin/moderador no hace nada.
class AdminApi {
  AdminApi(this._db);

  final SupabaseClient _db;
  static const _uuid = Uuid();

  Future<Map<String, dynamic>> _json(String fn, [Map<String, dynamic>? p]) async =>
      Map<String, dynamic>.from((await _db.rpc<dynamic>(fn, params: p)) as Map);

  Future<List<Map<String, dynamic>>> _list(String fn, [Map<String, dynamic>? p]) async =>
      ((await _db.rpc<dynamic>(fn, params: p)) as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  Future<Map<String, dynamic>> me() => _json('me');

  Future<Map<String, dynamic>> dashboard() => _json('admin_dashboard');

  // Novedades
  Future<List<Map<String, dynamic>>> news() async {
    final r = await _json('get_news', {'p_limit': 50});
    return [
      ...((r['destacadas'] as List?) ?? const []).cast<Map<dynamic, dynamic>>().map(
        Map<String, dynamic>.from,
      ),
      ...((r['items'] as List?) ?? const []).cast<Map<dynamic, dynamic>>().map(
        Map<String, dynamic>.from,
      ),
    ];
  }

  Future<void> publishNews({
    required String titulo,
    required String texto,
    String? etiqueta,
    bool fijado = false,
    String? id,
  }) => _db.rpc<dynamic>(
    'admin_publish_news',
    params: {
      'p_id': id ?? _uuid.v7(),
      'p_titulo': titulo,
      'p_texto': texto,
      'p_etiqueta': etiqueta,
      'p_fijado': fijado,
    },
  );

  Future<void> setPinned(String postId, {required bool pinned}) =>
      _db.rpc<dynamic>('admin_set_pinned', params: {'p_post': postId, 'p_fijado': pinned});

  Future<void> deletePost(String postId) =>
      _db.rpc<dynamic>('delete_post', params: {'p_id': postId});

  // Moderación
  Future<List<Map<String, dynamic>>> reports() => _list('admin_list_reports');

  /// accion: descartar | ocultar_contenido | suspender_socio
  Future<void> resolve(String reportId, String accion, {String? nota}) => _db.rpc<dynamic>(
    'admin_resolve_report',
    params: {'p_report': reportId, 'p_accion': accion, 'p_resolucion': nota},
  );

  // Clubs
  Future<List<Map<String, dynamic>>> clubs() => _list('list_clubs');

  Future<void> upsertClub({
    required String nombre,
    required String ciudad,
    required String pais,
    required double lat,
    required double lng,
    String? paisCode,
    String? descripcion,
    String? id,
  }) => _db.rpc<dynamic>(
    'admin_upsert_club',
    params: {
      'p_id': id ?? _uuid.v7(),
      'p_nombre': nombre,
      'p_ciudad': ciudad,
      'p_pais': pais,
      'p_lat': lat,
      'p_lng': lng,
      'p_pais_code': paisCode,
      'p_descripcion': descripcion,
    },
  );

  Future<void> deleteClub(String id) => _db.rpc<dynamic>('admin_delete_club', params: {'p_id': id});

  Future<void> setClubRole(String clubId, String userId, String rol) => _db.rpc<dynamic>(
    'admin_set_club_role',
    params: {'p_club': clubId, 'p_user': userId, 'p_rol': rol},
  );

  // Socios
  Future<List<Map<String, dynamic>>> members(String query) =>
      _list('admin_search_members', {'p_query': query.isEmpty ? null : query});

  Future<void> setRole(String userId, String role) =>
      _db.rpc<dynamic>('admin_set_member_role', params: {'p_user': userId, 'p_role': role});
}
