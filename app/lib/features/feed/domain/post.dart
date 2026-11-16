import 'package:icex_atlas/features/profiles/domain/profile.dart';

enum PostTipo {
  general('general'),
  evento('evento'),
  oportunidadLaboral('oportunidad_laboral'),
  logro('logro'),
  novedadOficial('novedad_oficial');

  const PostTipo(this.code);

  final String code;

  static PostTipo parse(String? code) =>
      PostTipo.values.firstWhere((t) => t.code == code, orElse: () => PostTipo.general);

  /// Tipos que un socio puede publicar desde el compositor.
  static const List<PostTipo> publicables = [general, evento, oportunidadLaboral, logro];

  /// Badge del mockup (las publicaciones generales no llevan badge).
  bool get hasBadge => this != general;
}

class SharedPost {
  const SharedPost({required this.id, required this.texto, required this.autor});

  factory SharedPost.fromJson(Map<String, dynamic> j) => SharedPost(
    id: j['id'] as String,
    texto: j['texto'] as String? ?? '',
    autor: ProfileCard.fromJson(Map<String, dynamic>.from(j['autor'] as Map)),
  );

  final String id;
  final String texto;
  final ProfileCard autor;
}

class Post {
  const Post({
    required this.id,
    required this.tipo,
    required this.texto,
    required this.autor,
    required this.createdAt,
    this.titulo,
    this.etiqueta,
    this.media = const [],
    this.fijado = false,
    this.recomendacionesCount = 0,
    this.comentariosCount = 0,
    this.compartidosCount = 0,
    this.recomendado = false,
    this.clubId,
    this.compartido,
  });

  factory Post.fromJson(Map<String, dynamic> j) => Post(
    id: j['id'] as String,
    tipo: PostTipo.parse(j['tipo'] as String?),
    texto: j['texto'] as String? ?? '',
    autor: ProfileCard.fromJson(Map<String, dynamic>.from(j['autor'] as Map)),
    createdAt: DateTime.parse(j['created_at'] as String),
    titulo: j['titulo'] as String?,
    etiqueta: j['etiqueta'] as String?,
    media: (j['media'] as List? ?? const []).cast<String>(),
    fijado: j['fijado'] as bool? ?? false,
    recomendacionesCount: (j['recomendaciones_count'] as num?)?.toInt() ?? 0,
    comentariosCount: (j['comentarios_count'] as num?)?.toInt() ?? 0,
    compartidosCount: (j['compartidos_count'] as num?)?.toInt() ?? 0,
    recomendado: j['recomendado'] as bool? ?? false,
    clubId: j['club_id'] as String?,
    compartido: j['compartido'] == null
        ? null
        : SharedPost.fromJson(Map<String, dynamic>.from(j['compartido'] as Map)),
  );

  final String id;
  final PostTipo tipo;
  final String texto;
  final ProfileCard autor;
  final DateTime createdAt;
  final String? titulo;
  final String? etiqueta;
  final List<String> media;
  final bool fijado;
  final int recomendacionesCount;
  final int comentariosCount;
  final int compartidosCount;
  final bool recomendado;
  final String? clubId;
  final SharedPost? compartido;

  /// Recomendación optimista (se corrige con la respuesta del servidor).
  Post toggleRecommendation() => copyWith(
    recomendado: !recomendado,
    recomendacionesCount: recomendacionesCount + (recomendado ? -1 : 1),
  );

  Post copyWith({bool? recomendado, int? recomendacionesCount, int? comentariosCount}) => Post(
    id: id,
    tipo: tipo,
    texto: texto,
    autor: autor,
    createdAt: createdAt,
    titulo: titulo,
    etiqueta: etiqueta,
    media: media,
    fijado: fijado,
    recomendacionesCount: recomendacionesCount ?? this.recomendacionesCount,
    comentariosCount: comentariosCount ?? this.comentariosCount,
    compartidosCount: compartidosCount,
    recomendado: recomendado ?? this.recomendado,
    clubId: clubId,
    compartido: compartido,
  );
}

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.texto,
    required this.autor,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    id: j['id'] as String,
    postId: j['post_id'] as String,
    texto: j['texto'] as String,
    autor: ProfileCard.fromJson(Map<String, dynamic>.from(j['autor'] as Map)),
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final String id;
  final String postId;
  final String texto;
  final ProfileCard autor;
  final DateTime createdAt;
}

/// Primera página del feed: las novedades fijadas van aparte (banner destacado).
class FeedPage {
  const FeedPage({required this.items, this.destacadas = const [], this.nextCursor});

  factory FeedPage.fromJson(Map<String, dynamic> j) => FeedPage(
    items: _posts(j['items']),
    destacadas: _posts(j['destacadas']),
    nextCursor: j['next_cursor'] as String?,
  );

  static List<Post> _posts(Object? raw) => (raw as List? ?? const [])
      .map((e) => Post.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();

  final List<Post> items;
  final List<Post> destacadas;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}
