import 'package:icex_atlas/features/profiles/domain/profile.dart';

enum Categoria {
  solicitudInformacion('solicitud_informacion'),
  oportunidadLaboral('oportunidad_laboral'),
  mentoria('mentoria'),
  networking('networking'),
  evento('evento'),
  colaboracionEmpresarial('colaboracion_empresarial');

  const Categoria(this.code);

  final String code;

  static Categoria parse(String? code) =>
      Categoria.values.firstWhere((c) => c.code == code, orElse: () => Categoria.networking);

  String get label => switch (this) {
    Categoria.solicitudInformacion => 'Solicitud de información',
    Categoria.oportunidadLaboral => 'Oportunidad laboral',
    Categoria.mentoria => 'Mentoría',
    Categoria.networking => 'Networking',
    Categoria.evento => 'Evento',
    Categoria.colaboracionEmpresarial => 'Colaboración empresarial',
  };
}

/// Estado de entrega de un mensaje propio (outbox en Drift + confirmación del servidor).
enum DeliveryStatus { enviando, enviado, leido, error }

class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.remitenteId,
    required this.cuerpo,
    required this.createdAt,
    this.status = DeliveryStatus.enviado,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
    id: j['id'] as String,
    conversationId: j['conversation_id'] as String,
    remitenteId: j['remitente_id'] as String? ?? '',
    cuerpo: j['cuerpo'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  final String id;
  final String conversationId;
  final String remitenteId;
  final String cuerpo;
  final DateTime createdAt;
  final DeliveryStatus status;

  Message withStatus(DeliveryStatus s) => Message(
    id: id,
    conversationId: conversationId,
    remitenteId: remitenteId,
    cuerpo: cuerpo,
    createdAt: createdAt,
    status: s,
  );
}

class Conversation {
  const Conversation({
    required this.id,
    required this.categoria,
    required this.otro,
    this.ultimoMensajeEn,
    this.ultimoMensajePreview,
    this.ultimoMensajeId,
    this.noLeidos = 0,
    this.silenciado = false,
    this.otroUltimoLeidoId,
  });

  factory Conversation.fromJson(Map<String, dynamic> j) {
    final otro = Map<String, dynamic>.from(j['otro'] as Map? ?? const {});
    return Conversation(
      id: j['id'] as String,
      categoria: Categoria.parse(j['categoria'] as String?),
      otro: ProfileCard.fromJson(otro),
      ultimoMensajeEn: j['ultimo_mensaje_en'] == null
          ? null
          : DateTime.parse(j['ultimo_mensaje_en'] as String),
      ultimoMensajePreview: j['ultimo_mensaje_preview'] as String?,
      ultimoMensajeId: j['ultimo_mensaje_id'] as String?,
      noLeidos: (j['no_leidos'] as num?)?.toInt() ?? 0,
      silenciado: j['silenciado'] as bool? ?? false,
      otroUltimoLeidoId: otro['ultimo_leido_id'] as String?,
    );
  }

  final String id;
  final Categoria categoria;
  final ProfileCard otro;
  final DateTime? ultimoMensajeEn;
  final String? ultimoMensajePreview;
  final String? ultimoMensajeId;
  final int noLeidos;
  final bool silenciado;

  /// Hasta dónde ha leído la otra persona (doble check). UUIDv7 → orden temporal.
  final String? otroUltimoLeidoId;

  bool isReadByOther(String messageId) =>
      otroUltimoLeidoId != null && otroUltimoLeidoId!.compareTo(messageId) >= 0;
}
