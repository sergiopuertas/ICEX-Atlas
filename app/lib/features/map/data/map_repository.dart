import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/features/map/domain/map_models.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';

class Bounds {
  const Bounds({required this.west, required this.south, required this.east, required this.north});

  final double west;
  final double south;
  final double east;
  final double north;
}

class MapRepository {
  const MapRepository(this._api);

  final ApiClient _api;

  Future<MapViewData> clusters({
    required int zoom,
    required Bounds bounds,
    Set<Fase>? fases,
    bool includeClubs = true,
  }) async => MapViewData.fromJson(
    await _api.rpcJson('map_clusters', {
      'p_zoom': zoom,
      'p_west': bounds.west,
      'p_south': bounds.south,
      'p_east': bounds.east,
      'p_north': bounds.north,
      'p_fases': fases == null || fases.length == Fase.values.length
          ? null
          : fases.map((f) => f.code).toList(),
      'p_include_clubs': includeClubs,
    }),
  );

  Future<List<ProfileCard>> alumniNear(double lat, double lng, {double radiusKm = 25}) async =>
      (await _api.rpcList('alumni_near', {
        'p_lat': lat,
        'p_lng': lng,
        'p_radius_km': radiusKm,
      })).map(ProfileCard.fromJson).toList();
}

class ClubsRepository {
  const ClubsRepository(this._api);

  final ApiClient _api;

  Future<List<Club>> list({String? query}) async =>
      (await _api.rpcList('list_clubs', {'p_query': query})).map(Club.fromJson).toList();

  Future<Club> get(String id) async =>
      Club.fromJson(await _api.rpcJson('get_club', {'p_club': id}));

  Future<Club> join(String id) async =>
      Club.fromJson(await _api.rpcJson('join_club', {'p_club': id}));

  Future<Club> leave(String id) async =>
      Club.fromJson(await _api.rpcJson('leave_club', {'p_club': id}));

  Future<List<ClubEvent>> events({String? clubId}) async =>
      (await _api.rpcList('list_events', {'p_club': clubId})).map(ClubEvent.fromJson).toList();

  Future<ClubEvent> register(String eventId) async =>
      ClubEvent.fromJson(await _api.rpcJson('register_event', {'p_event': eventId}));

  Future<ClubEvent> cancel(String eventId) async =>
      ClubEvent.fromJson(await _api.rpcJson('cancel_event_registration', {'p_event': eventId}));
}
