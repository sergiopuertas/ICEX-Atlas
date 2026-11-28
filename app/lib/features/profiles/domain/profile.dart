/// Fase del programa de Becas ICEX.
enum Fase {
  fase0('fase_0'),
  fase1('fase_1'),
  fase2('fase_2'),
  activo('activo');

  const Fase(this.code);

  final String code;

  static Fase parse(String? code) =>
      Fase.values.firstWhere((f) => f.code == code, orElse: () => Fase.activo);

  /// Etiqueta corta del badge (como en el mockup).
  String get label => switch (this) {
    Fase.fase0 => 'Fase 0',
    Fase.fase1 => 'Fase I',
    Fase.fase2 => 'Fase II',
    Fase.activo => 'ACTIVO',
  };
}

/// Visibilidad de un campo del perfil.
enum Visibilidad {
  socios('socios'),
  seguidores('seguidores'),
  soloYo('solo_yo');

  const Visibilidad(this.code);

  final String code;

  static Visibilidad parse(String? code) =>
      Visibilidad.values.firstWhere((v) => v.code == code, orElse: () => Visibilidad.socios);
}

/// Tarjeta de perfil con la privacidad ya aplicada por el servidor (campos ocultos = null).
class ProfileCard {
  const ProfileCard({
    required this.userId,
    required this.slug,
    required this.nombre,
    required this.fase,
    required this.promocion,
    this.cargo,
    this.empresa,
    this.pais,
    this.ciudad,
    this.sector,
    this.fotoPath,
    this.seguidoresCount = 0,
    this.siguiendoCount = 0,
    this.isFollowing = false,
  });

  factory ProfileCard.fromJson(Map<String, dynamic> j) => ProfileCard(
    userId: j['user_id'] as String,
    slug: j['slug'] as String? ?? '',
    nombre: j['nombre'] as String? ?? '',
    fase: Fase.parse(j['fase'] as String?),
    promocion: (j['promocion'] as num?)?.toInt() ?? 0,
    cargo: j['cargo'] as String?,
    empresa: j['empresa'] as String?,
    pais: j['pais'] as String?,
    ciudad: j['ciudad'] as String?,
    sector: j['sector'] as String?,
    fotoPath: j['foto_path'] as String?,
    seguidoresCount: (j['seguidores_count'] as num?)?.toInt() ?? 0,
    siguiendoCount: (j['siguiendo_count'] as num?)?.toInt() ?? 0,
    isFollowing: j['is_following'] as bool? ?? false,
  );

  final String userId;
  final String slug;
  final String nombre;
  final Fase fase;
  final int promocion;
  final String? cargo;
  final String? empresa;
  final String? pais;
  final String? ciudad;
  final String? sector;
  final String? fotoPath;
  final int seguidoresCount;
  final int siguiendoCount;
  final bool isFollowing;

  /// "Export Manager en Sener" (como el mockup), tolerando campos ocultos.
  String get headline => switch ((cargo, empresa)) {
    (final String c, final String e) => '$c en $e',
    (final String c, null) => c,
    (null, final String e) => e,
    _ => '',
  };

  String get location => [ciudad, pais].whereType<String>().join(', ');

  String get initials {
    final parts = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final second = parts.length > 1 ? parts[1][0] : '';
    return (parts.first[0] + second).toUpperCase();
  }

  ProfileCard copyWith({bool? isFollowing, int? seguidoresCount}) => ProfileCard(
    userId: userId,
    slug: slug,
    nombre: nombre,
    fase: fase,
    promocion: promocion,
    cargo: cargo,
    empresa: empresa,
    pais: pais,
    ciudad: ciudad,
    sector: sector,
    fotoPath: fotoPath,
    seguidoresCount: seguidoresCount ?? this.seguidoresCount,
    siguiendoCount: siguiendoCount,
    isFollowing: isFollowing ?? this.isFollowing,
  );
}

class Experience {
  const Experience({
    required this.id,
    required this.empresa,
    required this.cargo,
    required this.desde,
    this.hasta,
  });

  factory Experience.fromJson(Map<String, dynamic> j) => Experience(
    id: j['id'] as String,
    empresa: j['empresa'] as String,
    cargo: j['cargo'] as String,
    desde: DateTime.parse(j['desde'] as String),
    hasta: j['hasta'] == null ? null : DateTime.parse(j['hasta'] as String),
  );

  final String id;
  final String empresa;
  final String cargo;
  final DateTime desde;
  final DateTime? hasta;

  bool get isCurrent => hasta == null;
}

class ProfileDetail {
  const ProfileDetail({
    required this.card,
    this.bio,
    this.postsCount = 0,
    this.experiences = const [],
    this.isSelf = false,
    this.followsMe = false,
    this.visibilidad = const {},
    this.aceptaSugerencias,
  });

  factory ProfileDetail.fromJson(Map<String, dynamic> j) => ProfileDetail(
    card: ProfileCard.fromJson(j),
    bio: j['bio'] as String?,
    postsCount: (j['posts_count'] as num?)?.toInt() ?? 0,
    experiences: (j['experiences'] as List? ?? const [])
        .map((e) => Experience.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    isSelf: j['is_self'] as bool? ?? false,
    followsMe: j['follows_me'] as bool? ?? false,
    visibilidad: (j['visibilidad'] as Map? ?? const {}).map(
      (k, v) => MapEntry(k as String, Visibilidad.parse(v as String?)),
    ),
    aceptaSugerencias: j['acepta_sugerencias'] as bool?,
  );

  final ProfileCard card;
  final String? bio;
  final int postsCount;
  final List<Experience> experiences;
  final bool isSelf;
  final bool followsMe;
  final Map<String, Visibilidad> visibilidad;
  final bool? aceptaSugerencias;

  ProfileDetail withExperiences(List<Experience> experiences) => copyWith(experiences: experiences);

  ProfileDetail copyWith({ProfileCard? card, List<Experience>? experiences}) => ProfileDetail(
    card: card ?? this.card,
    bio: bio,
    postsCount: postsCount,
    experiences: experiences ?? this.experiences,
    isSelf: isSelf,
    followsMe: followsMe,
    visibilidad: visibilidad,
    aceptaSugerencias: aceptaSugerencias,
  );
}

/// Usuario de la sesión (api.me()).
class Me {
  const Me({
    required this.userId,
    required this.role,
    required this.profile,
    this.origen = 'alumni',
  });

  factory Me.fromJson(Map<String, dynamic> j) => Me(
    userId: j['user_id'] as String,
    role: j['role'] as String? ?? 'socio',
    origen: j['origen'] as String? ?? 'alumni',
    profile: ProfileDetail.fromJson(Map<String, dynamic>.from(j['profile'] as Map? ?? const {})),
  );

  final String userId;
  final String role;
  final ProfileDetail profile;

  /// `alumni` (verificado por ICEX Alumni) o `beta` (cuenta de email de la beta abierta).
  final String origen;

  bool get isBetaAccount => origen == 'beta';

  bool get isAdmin => role == 'admin';
  bool get isModerator => role == 'moderador' || isAdmin;
}

class CommunityStats {
  const CommunityStats({
    required this.alumni,
    required this.activos,
    required this.paises,
    required this.promociones,
    this.promocionActual,
  });

  factory CommunityStats.fromJson(Map<String, dynamic> j) => CommunityStats(
    alumni: (j['alumni'] as num?)?.toInt() ?? 0,
    activos: (j['activos'] as num?)?.toInt() ?? 0,
    paises: (j['paises'] as num?)?.toInt() ?? 0,
    promociones: (j['promociones'] as num?)?.toInt() ?? 0,
    promocionActual: (j['promocion_actual'] as num?)?.toInt(),
  );

  final int alumni;
  final int activos;
  final int paises;
  final int promociones;

  /// Promoción en curso según el servidor (puede fijarse a mano en config).
  final int? promocionActual;
}

/// Promoción en curso: cada año entra una nueva (2026 → 51ª, en Fase 0).
/// Misma regla que `profiles.current_promocion()` en la base de datos; si el servidor
/// envía otro valor (ajuste manual), manda el del servidor.
int currentPromocion({DateTime? now, int? fromServer}) =>
    fromServer ?? (now ?? DateTime.now()).year - 1975;
