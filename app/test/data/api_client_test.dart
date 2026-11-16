import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/core/errors/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SupabaseApiClient contra un servidor HTTP local que imita PostgREST, Functions y Storage.
void main() {
  late HttpServer server;
  late SupabaseApiClient api;
  final hits = <String>[];

  setUpAll(() async {
    // flutter_test intercepta HTTP (devuelve 400); aquí queremos peticiones reales a localhost.
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0)
      ..listen((req) async {
        hits.add('${req.method} ${req.uri.path}');
        final res = req.response..headers.contentType = ContentType.json;
        void send(int status, Object body) {
          res
            ..statusCode = status
            ..write(jsonEncode(body));
        }

        switch (req.uri.path) {
          case '/rest/v1/rpc/me':
            send(200, {'user_id': 'u-1'});
          case '/rest/v1/rpc/forbidden':
            send(403, {
              'code': '42501',
              'message': 'Acceso solo para socios',
              'details': null,
              'hint': null,
            });
          case '/rest/v1/rpc/limited':
            send(400, {
              'code': 'P0001',
              'message': 'Límite',
              'details': null,
              'hint': 'rate_limited',
            });
          case '/functions/v1/orientador':
            send(429, {'error': 'rate_limited', 'message': 'Has alcanzado el límite'});
          case '/functions/v1/media-upload':
            send(201, {'path': 'u-1/x.jpg', 'q': req.uri.queryParameters['bucket']});
          case final p when p.startsWith('/storage/v1/object/sign/'):
            send(200, {'signedURL': '/object/sign/avatars/u-1/x.jpg?token=t'});
          default:
            send(404, {'code': 'PGRST202', 'message': 'no existe'});
        }
        await res.close();
      });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'anon-key',
      postgrestOptions: const PostgrestClientOptions(schema: 'api'),
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    api = SupabaseApiClient(client);
  });

  tearDownAll(() => server.close(force: true));

  test('rpc OK y errores traducidos a fallos de dominio', () async {
    expect(await api.rpcJson('me'), {'user_id': 'u-1'});
    await expectLater(api.rpc('forbidden'), throwsA(isA<ForbiddenFailure>()));
    await expectLater(api.rpc('limited'), throwsA(isA<RateLimitedFailure>()));
    await expectLater(api.rpc('nope'), throwsA(isA<NotFoundFailure>()));
  });

  test('Edge Functions: respuesta, query string y error HTTP', () async {
    final up = await api.uploadImage(Uint8List.fromList([1, 2, 3]), bucket: 'avatars');
    expect(up, 'u-1/x.jpg');
    await expectLater(
      api.invokeFunction('orientador', body: const {'fase': 'activo'}),
      throwsA(isA<RateLimitedFailure>()),
    );
  });

  test('URL firmada con transformación y caché en memoria', () async {
    final before = hits.where((h) => h.contains('/object/sign/')).length;
    final a = await api.signedUrl('avatars', 'u-1/x.jpg', width: 96, height: 96);
    final b = await api.signedUrl('avatars', 'u-1/x.jpg', width: 96, height: 96);
    expect(a, b);
    expect(a, contains('token=t'));
    expect(
      hits.where((h) => h.contains('/object/sign/')).length,
      before + 1,
      reason: 'segunda vez desde caché',
    );
  });

  test('sin conexión → NetworkFailure (el outbox lo deja pendiente)', () async {
    final dead = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = dead.port;
    await dead.close();
    final offline = SupabaseApiClient(
      SupabaseClient(
        'http://127.0.0.1:$port',
        'anon-key',
        postgrestOptions: const PostgrestClientOptions(schema: 'api'),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
    await expectLater(offline.rpc('me'), throwsA(isA<NetworkFailure>()));
    await expectLater(offline.invokeFunction('orientador'), throwsA(isA<NetworkFailure>()));
  });
}
