import 'dart:async';

import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/core/auth/auth_gateway.dart';
import 'package:icex_atlas/core/utils/ids.dart';
import 'package:icex_atlas/features/messaging/data/realtime_gateway.dart';

typedef Responder = Object? Function(Map<String, dynamic> params);

class Call {
  Call(this.name, this.params);

  final String name;
  final Map<String, dynamic> params;
}

/// Doble de ApiClient: respuestas por nombre de función RPC / Edge Function.
class FakeApiClient implements ApiClient {
  FakeApiClient([Map<String, Responder>? responders]) : responders = responders ?? {};

  final Map<String, Responder> responders;
  final calls = <Call>[];

  Call last(String name) => calls.lastWhere((c) => c.name == name);

  Object? _respond(String name, Map<String, dynamic> params) {
    calls.add(Call(name, params));
    final r = responders[name];
    if (r == null) throw StateError('Sin respuesta para $name');
    return r(params);
  }

  @override
  Future<Object?> rpc(String function, [Map<String, dynamic>? params]) async =>
      _respond(function, params ?? {});

  @override
  Future<Map<String, dynamic>> invokeFunction(
    String name, {
    Object? body,
    Map<String, String>? headers,
    Map<String, String>? query,
  }) async => Map<String, dynamic>.from(
    _respond(name, {'body': body, 'headers': headers, 'query': query})! as Map,
  );

  @override
  Future<String> signedUrl(String bucket, String path, {int? width, int? height}) async =>
      'https://example.invalid/$bucket/$path?w=$width';
}

/// Lanza un fallo concreto (para probar ramas de error).
Responder failWith(Exception error) =>
    (_) => throw error;

class FakeIds implements IdGenerator {
  FakeIds([this.prefix = '01900000-0000-7000-8000-']);

  final String prefix;
  int _n = 0;

  @override
  String next() => '$prefix${(++_n).toString().padLeft(12, '0')}';
}

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.currentUserId});

  @override
  String? currentUserId;
  final _events = StreamController<AuthEvent>.broadcast();
  int signInCalls = 0;
  int signOutCalls = 0;

  void emit(AuthEvent e) => _events.add(e);

  @override
  Stream<AuthEvent> get events => _events.stream;

  @override
  Future<void> signIn() async => signInCalls++;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    currentUserId = null;
  }
}

class FakeRealtime implements RealtimeGateway {
  final conversations = <String, StreamController<ConversationEvent>>{};
  final users = <String, StreamController<String>>{};

  @override
  Stream<ConversationEvent> conversation(String conversationId) =>
      (conversations[conversationId] ??= StreamController.broadcast()).stream;

  @override
  Stream<String> userEvents(String userId) =>
      (users[userId] ??= StreamController.broadcast()).stream;
}

// ------------------------------------------------------------------ fixtures --

Map<String, dynamic> cardJson({
  String id = 'u-1',
  String nombre = 'Ana Ortega Jiménez',
  String fase = 'activo',
  int promocion = 49,
  String? cargo = 'Business Development Manager',
  String? empresa = 'ACS',
  bool following = false,
}) => {
  'user_id': id,
  'slug': 'ana-ortega-$id',
  'nombre': nombre,
  'fase': fase,
  'promocion': promocion,
  'cargo': cargo,
  'empresa': empresa,
  'pais': 'Perú',
  'ciudad': 'Lima',
  'sector': 'Infraestructuras',
  'foto_path': null,
  'seguidores_count': 1350,
  'siguiendo_count': 19,
  'is_following': following,
};

Map<String, dynamic> postJson({
  String id = 'p-1',
  String tipo = 'general',
  bool recomendado = false,
  int recos = 76,
  Map<String, dynamic>? autor,
  String createdAt = '2026-11-16T12:00:00Z',
}) => {
  'id': id,
  'tipo': tipo,
  'texto': '¿Preparando tu llegada a Singapur? Estos son mis tres imprescindibles.',
  'media': <String>[],
  'fijado': false,
  'recomendaciones_count': recos,
  'comentarios_count': 18,
  'compartidos_count': 0,
  'created_at': createdAt,
  'recomendado': recomendado,
  'autor': autor ?? cardJson(id: 'u-2', nombre: 'Javier Martín Jiménez', promocion: 42),
  '_cursor': 'c-$id',
};

Map<String, dynamic> meJson({String id = 'u-1', String role = 'socio'}) => {
  'user_id': id,
  'role': role,
  'profile': {
    ...cardJson(id: id),
    'bio': 'Bio',
    'visibilidad': {'empresa': 'socios'},
    'acepta_sugerencias': true,
  },
};

Map<String, dynamic> messageJson(
  String id, {
  String conv = 'c-1',
  String from = 'u-2',
  String cuerpo = 'Hola',
}) => {
  'id': id,
  'conversation_id': conv,
  'remitente_id': from,
  'cuerpo': cuerpo,
  'created_at': '2026-11-16T12:00:00Z',
};
