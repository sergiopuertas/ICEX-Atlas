import 'package:icex_atlas/features/profiles/domain/profile.dart';

enum NotificationTipo {
  nuevoSeguidor,
  recomendacion,
  comentario,
  mensaje,
  evento,
  novedad,
  sistema,
}

NotificationTipo _parseTipo(String? s) => switch (s) {
  'nuevo_seguidor' => NotificationTipo.nuevoSeguidor,
  'recomendacion' => NotificationTipo.recomendacion,
  'comentario' => NotificationTipo.comentario,
  'mensaje' => NotificationTipo.mensaje,
  'evento' => NotificationTipo.evento,
  'novedad' => NotificationTipo.novedad,
  _ => NotificationTipo.sistema,
};

class AppNotification {
  const AppNotification({
    required this.id,
    required this.tipo,
    required this.total,
    required this.leido,
    required this.updatedAt,
    this.actores = const [],
    this.payload = const {},
  });

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    tipo: _parseTipo(j['tipo'] as String?),
    total: (j['total'] as num?)?.toInt() ?? 1,
    leido: j['leido'] as bool? ?? false,
    updatedAt: DateTime.parse((j['updated_at'] ?? j['created_at']) as String),
    actores: (j['actores'] as List? ?? const [])
        .map((e) => ProfileCard.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList(),
    payload: Map<String, dynamic>.from(j['payload'] as Map? ?? const {}),
  );

  final String id;
  final NotificationTipo tipo;
  final int total;
  final bool leido;
  final DateTime updatedAt;
  final List<ProfileCard> actores;
  final Map<String, dynamic> payload;

  String? get postId => payload['post_id'] as String?;

  /// Ruta interna a la que lleva la notificación.
  String get route => switch (tipo) {
    NotificationTipo.nuevoSeguidor when actores.isNotEmpty => '/perfil/${actores.first.slug}',
    NotificationTipo.mensaje when payload['conversation_id'] != null =>
      '/mensajes/${payload['conversation_id']}',
    _ when postId != null => '/post/$postId',
    _ => '/notificaciones',
  };
}

class NotificationPreferences {
  const NotificationPreferences({
    this.pushMensajes = true,
    this.pushSocial = true,
    this.pushEventos = true,
    this.pushNovedades = true,
    this.emailNovedades = false,
    this.emailResumenSemanal = false,
    this.consentimientoComunicaciones = false,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> j) => NotificationPreferences(
    pushMensajes: j['push_mensajes'] as bool? ?? true,
    pushSocial: j['push_social'] as bool? ?? true,
    pushEventos: j['push_eventos'] as bool? ?? true,
    pushNovedades: j['push_novedades'] as bool? ?? true,
    emailNovedades: j['email_novedades'] as bool? ?? false,
    emailResumenSemanal: j['email_resumen_semanal'] as bool? ?? false,
    consentimientoComunicaciones: j['consentimiento_comunicaciones'] as bool? ?? false,
  );

  final bool pushMensajes;
  final bool pushSocial;
  final bool pushEventos;
  final bool pushNovedades;
  final bool emailNovedades;
  final bool emailResumenSemanal;
  final bool consentimientoComunicaciones;

  Map<String, dynamic> toJson() => {
    'push_mensajes': pushMensajes,
    'push_social': pushSocial,
    'push_eventos': pushEventos,
    'push_novedades': pushNovedades,
    'email_novedades': emailNovedades,
    'email_resumen_semanal': emailResumenSemanal,
    'consentimiento_comunicaciones': consentimientoComunicaciones,
  };
}
