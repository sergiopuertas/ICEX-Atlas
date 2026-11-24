import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/features/feed/presentation/post_card.dart';
import 'package:icex_atlas/features/messaging/data/realtime_gateway.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';

/// Presupuestos de latencia: cuántas peticiones hace cada flujo y cuánto se reconstruye.
///
/// Medir milisegundos en CI no es fiable; contar peticiones y reconstrucciones sí, y es
/// lo que determina la latencia percibida (cada petición son 50–300 ms en móvil). Si un
/// cambio duplica consultas o reconstrucciones, estos tests fallan.
int count(FakeApiClient api, String name) => api.calls.where((c) => c.name == name).length;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('Arranque', () {
    testWidgets('Inicio pide cada dato una sola vez', (t) async {
      final api = fullDemoApi();
      await pumpApp(t, appHarness(api));
      for (final rpc in ['me', 'get_feed', 'unread_counts']) {
        expect(count(api, rpc), 1, reason: '$rpc duplicada al arrancar');
      }
      // Las sugerencias se piden al llegar a ellas (tras la 3.ª publicación), no al abrir.
      expect(count(api, 'suggestions'), lessThanOrEqualTo(1));
      // Inicio ya no muestra «La comunidad en cifras»: no debe pedirse.
      expect(count(api, 'community_stats'), 0);
      expect(
        api.calls.length,
        lessThanOrEqualTo(5),
        reason: api.calls.map((c) => c.name).join(', '),
      );
    });

    testWidgets('cambiar de pestaña y volver no recarga el feed', (t) async {
      final api = fullDemoApi();
      await pumpApp(t, appHarness(api));
      await goTo(t, '/red');
      await goTo(t, '/mensajes');
      await goTo(t, '/');
      expect(count(api, 'get_feed'), 1);
      await goTo(t, '/red');
      expect(count(api, 'search_directory'), 1, reason: 'la Red conserva sus resultados');
    });
  });

  group('Tiempo real', () {
    testWidgets('una ráfaga de 10 eventos = 1 consulta de contadores y 1 de conversaciones', (
      t,
    ) async {
      final api = fullDemoApi();
      final rt = FakeRealtime();
      await pumpApp(t, appHarness(api, realtime: rt), location: '/mensajes');
      final unread0 = count(api, 'unread_counts');
      final convs0 = count(api, 'list_conversations');
      final events = rt.users['u-1']!;
      for (var i = 0; i < 10; i++) {
        events.add('mensaje');
        await t.pump(const Duration(milliseconds: 30));
      }
      await settleData(t, frames: 20);
      expect(count(api, 'unread_counts') - unread0, 1);
      expect(count(api, 'list_conversations') - convs0, 1);
    });

    testWidgets('chat: 5 mensajes seguidos = 1 «marcar como leído»', (t) async {
      final api = fullDemoApi();
      final rt = FakeRealtime();
      await pumpApp(t, appHarness(api, realtime: rt), location: '/mensajes/c0');
      await settleData(t, frames: 20);
      final read0 = count(api, 'mark_read');
      final conv = rt.conversations['c0']!;
      for (var i = 0; i < 5; i++) {
        conv.add(
          MessageCreated(
            Message.fromJson({
              ...messageJson(
                '01900000-0000-7000-8000-0000000009${i.toString().padLeft(2, '0')}',
                conv: 'c0',
              ),
              'created_at': DateTime.now().toUtc().toIso8601String(),
            }),
          ),
        );
        await t.pump(const Duration(milliseconds: 40));
      }
      await settleData(t, frames: 20);
      expect(count(api, 'mark_read') - read0, 1);
    });
  });

  group('Búsqueda', () {
    testWidgets('escribir «ingeniera» letra a letra = 1 búsqueda', (t) async {
      final api = fullDemoApi();
      await pumpApp(t, appHarness(api), location: '/red');
      final before = count(api, 'search_directory');
      const word = 'ingeniera';
      for (var i = 1; i <= word.length; i++) {
        await t.enterText(find.byKey(const Key('directory-search')), word.substring(0, i));
        await t.pump(const Duration(milliseconds: 60));
      }
      await settleData(t, frames: 20);
      expect(count(api, 'search_directory') - before, 1);
    });
  });

  group('Reconstrucciones', () {
    testWidgets('recomendar una publicación reconstruye solo esa tarjeta', (t) async {
      final api = fullDemoApi()
        ..responders['recommend'] = (_) => {'recomendado': true, 'recomendaciones_count': 77};
      await pumpApp(t, appHarness(api));
      var rebuilt = 0;
      debugOnRebuildDirtyWidget = (e, _) {
        if (e.widget is PostCard) rebuilt++;
      };
      addTearDown(() => debugOnRebuildDirtyWidget = null);
      await t.tap(find.bySemanticsLabel('Recomendar').first);
      await settleData(t);
      expect(rebuilt, lessThanOrEqualTo(2), reason: 'optimista + respuesta, solo esa tarjeta');
      expect(count(api, 'recommend'), 1);
    });
  });

  group('Imágenes', () {
    test('20 avatares de la misma persona a la vez = 1 URL firmada', () async {
      var requests = 0;
      final client = SupabaseClient(
        'http://localhost:54321',
        'anon',
        httpClient: MockClient((req) async {
          requests++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(
            jsonEncode({'signedURL': '/object/sign/avatars/u1.jpg?token=x'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final api = SupabaseApiClient(client);
      final urls = await Future.wait([
        for (var i = 0; i < 20; i++) api.signedUrl('avatars', 'u1.jpg', width: 128, height: 128),
      ]);
      expect(urls.toSet(), hasLength(1));
      expect(requests, 1);
      // Y en caché después.
      await api.signedUrl('avatars', 'u1.jpg', width: 128, height: 128);
      expect(requests, 1);
    });
  });
}
