import 'package:icex_atlas/features/profiles/domain/profile.dart';

/// Cluster calculado en SQL (PostGIS, rejilla por zoom). `alumni` solo si count == 1.
class MapCluster {
  const MapCluster({required this.lat, required this.lng, required this.count, this.alumni});

  factory MapCluster.fromJson(Map<String, dynamic> j) => MapCluster(
    lat: (j['lat'] as num).toDouble(),
    lng: (j['lng'] as num).toDouble(),
    count: (j['count'] as num).toInt(),
    alumni: j['alumni'] == null
        ? null
        : ProfileCard.fromJson(Map<String, dynamic>.from(j['alumni'] as Map)),
  );

  final double lat;
  final double lng;
  final int count;
  final ProfileCard? alumni;

  bool get isSingle => count == 1 && alumni != null;
}

class Club {
  const Club({
    required this.id,
    required this.nombre,
    required this.ciudad,
    required this.pais,
    required this.lat,
    required this.lng,
    this.miembrosCount = 0,
    this.descripcion,
    this.miRol,
    this.proximosEventos = const [],
  });

  factory Club.fromJson(Map<String, dynamic> j) => Club(
    id: j['id'] as String,
    nombre: j['nombre'] as String,
    ciudad: j['ciudad'] as String? ?? '',
    pais: j['pais'] as String? ?? '',
    lat: (j['lat'] as num?)?.toDouble() ?? 0,
    lng: (j['lng'] as num?)?.toDouble() ?? 0,
    miembrosCount: (j['miembros_count'] as num?)?.toInt() ?? 0,
    descripcion: j['descripcion'] as String?,
    miRol: j['mi_rol'] as String?,
    proximosEventos: (j['proximos_eventos'] as List? ?? const [])
        .map((e) => ClubEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
  );

  final String id;
  final String nombre;
  final String ciudad;
  final String pais;
  final double lat;
  final double lng;
  final int miembrosCount;
  final String? descripcion;
  final String? miRol;
  final List<ClubEvent> proximosEventos;

  bool get isMember => miRol != null;
}

enum Inscripcion { ninguna, inscrito, listaEspera }

class ClubEvent {
  const ClubEvent({
    required this.id,
    required this.clubId,
    required this.titulo,
    required this.inicio,
    this.fin,
    this.lugar,
    this.onlineUrl,
    this.aforo,
    this.inscritosCount = 0,
    this.descripcion,
    this.clubNombre,
    this.inscripcion = Inscripcion.ninguna,
  });

  factory ClubEvent.fromJson(Map<String, dynamic> j) => ClubEvent(
    id: j['id'] as String,
    clubId: j['club_id'] as String,
    titulo: j['titulo'] as String,
    inicio: DateTime.parse(j['inicio'] as String),
    fin: j['fin'] == null ? null : DateTime.parse(j['fin'] as String),
    lugar: j['lugar'] as String?,
    onlineUrl: j['online_url'] as String?,
    aforo: (j['aforo'] as num?)?.toInt(),
    inscritosCount: (j['inscritos_count'] as num?)?.toInt() ?? 0,
    descripcion: j['descripcion'] as String?,
    clubNombre: j['club_nombre'] as String?,
    inscripcion: switch (j['mi_inscripcion']) {
      'inscrito' => Inscripcion.inscrito,
      'lista_espera' => Inscripcion.listaEspera,
      _ => Inscripcion.ninguna,
    },
  );

  final String id;
  final String clubId;
  final String titulo;
  final DateTime inicio;
  final DateTime? fin;
  final String? lugar;
  final String? onlineUrl;
  final int? aforo;
  final int inscritosCount;
  final String? descripcion;
  final String? clubNombre;
  final Inscripcion inscripcion;

  bool get isFull => aforo != null && inscritosCount >= aforo!;
}

class MapViewData {
  const MapViewData({required this.clusters, required this.clubs, required this.total});

  factory MapViewData.fromJson(Map<String, dynamic> j) => MapViewData(
    clusters: (j['clusters'] as List? ?? const [])
        .map((e) => MapCluster.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    clubs: (j['clubs'] as List? ?? const [])
        .map((e) => Club.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    total: (j['total'] as num?)?.toInt() ?? 0,
  );

  static const empty = MapViewData(clusters: [], clubs: [], total: 0);

  final List<MapCluster> clusters;
  final List<Club> clubs;
  final int total;
}
