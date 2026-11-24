import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/core/auth/auth_gateway.dart';
import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/db/app_database.dart';
import 'package:icex_atlas/core/errors/failure.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/utils/debouncer.dart';
import 'package:icex_atlas/features/directory/application/directory_controller.dart';
import 'package:icex_atlas/features/directory/data/directory_repository.dart';
import 'package:icex_atlas/features/feed/application/feed_controller.dart';
import 'package:icex_atlas/features/feed/application/post_interactions.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/messaging/application/chat_controller.dart';
import 'package:icex_atlas/features/messaging/data/realtime_gateway.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';

import '../helpers/fakes.dart';

ProviderContainer container(
  FakeApiClient api, {
  FakeAuthGateway? auth,
  FakeRealtime? rt,
  AppDatabase? db,
}) {
  final c = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authGatewayProvider.overrideWithValue(auth ?? FakeAuthGateway()),
      realtimeGatewayProvider.overrideWithValue(rt ?? FakeRealtime()),
      appDatabaseProvider.overrideWithValue(db ?? AppDatabase(NativeDatabase.memory())),
      idGeneratorProvider.overrideWithValue(FakeIds()),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 20));

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('SessionController', () {
    test('sin sesión → SignedOut; login OK → SignedIn con api.me()', () async {
      final auth = FakeAuthGateway();
      final c = container(FakeApiClient({'me': (_) => meJson()}), auth: auth);
      expect(c.read(sessionControllerProvider), isA<SignedOut>());
      await c.read(sessionControllerProvider.notifier).signIn();
      expect(auth.signInCalls, 1);
      auth.emit(const AuthSignedIn('u-1'));
      await settle();
      final s = c.read(sessionControllerProvider);
      expect(s, isA<SignedIn>());
      expect((s as SignedIn).me.profile.card.nombre, 'Ana Ortega Jiménez');
    });

    test('el hook rechaza al no socio → AccessDenied', () async {
      final auth = FakeAuthGateway();
      final c = container(FakeApiClient(), auth: auth)..read(sessionControllerProvider);
      auth.emit(const AuthFailed('icex_member_not_verified'));
      await settle();
      expect(c.read(sessionControllerProvider), isA<AccessDenied>());
      c.read(sessionControllerProvider.notifier).reset();
      expect(c.read(sessionControllerProvider), isA<SignedOut>());
    });

    test('JWT válido pero baja (42501 en api.me) → AccessDenied y cierre de sesión', () async {
      final auth = FakeAuthGateway(currentUserId: 'u-1');
      final c = container(
        FakeApiClient({'me': failWith(const ForbiddenFailure('no socio'))}),
        auth: auth,
      );
      expect(c.read(sessionControllerProvider), isA<SessionUnknown>());
      await settle();
      expect(c.read(sessionControllerProvider), isA<AccessDenied>());
      expect(auth.signOutCalls, 1);
    });

    test('sin red al restaurar sesión → SignedOut(network); error OAuth genérico', () async {
      final auth = FakeAuthGateway(currentUserId: 'u-1');
      final c = container(FakeApiClient({'me': failWith(const NetworkFailure())}), auth: auth)
        ..read(sessionControllerProvider);
      await settle();
      expect((c.read(sessionControllerProvider) as SignedOut).error, 'network');
      auth.emit(const AuthFailed('otro error'));
      await settle();
      expect((c.read(sessionControllerProvider) as SignedOut).error, 'otro error');
    });

    test('signOut borra los datos locales', () async {
      final auth = FakeAuthGateway(currentUserId: 'u-1');
      final c = container(FakeApiClient({'me': (_) => meJson()}), auth: auth)
        ..read(sessionControllerProvider);
      await settle();
      await c.read(sessionControllerProvider.notifier).refreshMe();
      await c.read(sessionControllerProvider.notifier).signOut();
      expect(c.read(sessionControllerProvider), isA<SignedOut>());
      expect(auth.signOutCalls, 1);
      auth.emit(const AuthSignedOut());
      await settle();
      expect(c.read(sessionControllerProvider), isA<SignedOut>());
    });

    test('tras «solo socios», el siguiente acceso pide usuario de nuevo (prompt=login)', () async {
      final auth = FakeAuthGateway();
      final c = container(FakeApiClient(), auth: auth)..read(sessionControllerProvider);
      await c.read(sessionControllerProvider.notifier).signIn();
      expect(auth.lastForceLogin, isFalse, reason: 'primer acceso: SSO normal');
      auth.emit(const AuthFailed('icex_member_not_verified'));
      await settle();
      expect(c.read(sessionControllerProvider), isA<AccessDenied>());
      c.read(sessionControllerProvider.notifier).reset();
      await c.read(sessionControllerProvider.notifier).signIn();
      expect(auth.lastForceLogin, isTrue);
    });

    test('«Entrar con otra cuenta» fuerza el formulario del proveedor', () async {
      final auth = FakeAuthGateway();
      final c = container(FakeApiClient(), auth: auth)..read(sessionControllerProvider);
      await c.read(sessionControllerProvider.notifier).signIn(switchAccount: true);
      expect(auth.lastForceLogin, isTrue);
    });

    test('volver a la app sin completar el acceso reactiva el botón', () async {
      final auth = FakeAuthGateway();
      final c = container(FakeApiClient(), auth: auth)..read(sessionControllerProvider);
      await c.read(sessionControllerProvider.notifier).signIn();
      expect(c.read(sessionControllerProvider), isA<SigningIn>());
      c.read(sessionControllerProvider.notifier).signInAbandoned();
      expect(c.read(sessionControllerProvider), isA<SignedOut>());
    });

    test('refreshMe sin red conserva la sesión (antes echaba al login)', () async {
      final auth = FakeAuthGateway(currentUserId: 'u-1');
      final api = FakeApiClient({'me': (_) => meJson()});
      final c = container(api, auth: auth)..read(sessionControllerProvider);
      await settle();
      expect(c.read(sessionControllerProvider), isA<SignedIn>());
      api.responders['me'] = failWith(const NetworkFailure());
      await c.read(sessionControllerProvider.notifier).refreshMe();
      expect(c.read(sessionControllerProvider), isA<SignedIn>());
    });

    test(
      'sessionUserId no cambia al recargar el perfil (push/presencia no se reinician)',
      () async {
        final auth = FakeAuthGateway(currentUserId: 'u-1');
        final c = container(FakeApiClient({'me': (_) => meJson()}), auth: auth)
          ..read(sessionControllerProvider);
        await settle();
        var changes = 0;
        c.listen(sessionUserIdProvider, (_, _) => changes++);
        expect(c.read(sessionUserIdProvider), 'u-1');
        await c.read(sessionControllerProvider.notifier).refreshMe();
        await c.read(sessionControllerProvider.notifier).refreshMe();
        expect(changes, 0);
      },
    );
  });

  group('FeedController', () {
    test('carga, paginación, recomendación optimista y publicación', () async {
      var recommendFails = false;
      final api = FakeApiClient({
        'get_feed': (p) => p['p_cursor'] == null
            ? {
                'items': [postJson(id: 'p1'), postJson(id: 'p2')],
                'destacadas': [postJson(id: 'n1', tipo: 'novedad_oficial')],
                'next_cursor': 'c2',
              }
            : {
                'items': [postJson(id: 'p3')],
                'next_cursor': null,
              },
        'recommend': (_) => recommendFails
            ? throw const NetworkFailure()
            : {'recomendado': true, 'recomendaciones_count': 77},
        'create_post': (p) => postJson(id: p['p_id'] as String),
        'delete_post': (_) => null,
        'media-upload': (_) => {'path': 'u-1/x.jpg'},
      });
      final c = container(api);
      final s = await c.read(feedControllerProvider.future);
      expect(s.posts.map((p) => p.id), ['p1', 'p2']);
      expect(s.destacadas.single.id, 'n1');

      await c.read(feedControllerProvider.notifier).loadMore();
      expect(c.read(feedControllerProvider).value!.posts.map((p) => p.id), ['p1', 'p2', 'p3']);
      expect(c.read(feedControllerProvider).value!.hasMore, isFalse);
      await c.read(feedControllerProvider.notifier).loadMore(); // sin más páginas: no llama

      // Recomendar / comentar / borrar viven en el estado compartido (PostOverrides): la
      // misma publicación se ve igual en Inicio, perfil y detalle.
      Post shown(Post p) => c.read(postOverridesProvider).resolve(p)!;
      final p1 = c.read(feedControllerProvider).value!.posts.first;
      await c.read(postOverridesProvider.notifier).toggleRecommend(p1);
      expect(shown(p1).recomendado, isTrue);
      expect(shown(p1).recomendacionesCount, 77);

      recommendFails = true;
      final p2 = c.read(feedControllerProvider).value!.posts[1];
      await expectLater(
        c.read(postOverridesProvider.notifier).toggleRecommend(p2),
        throwsA(isA<NetworkFailure>()),
      );
      expect(shown(p2).recomendado, isFalse, reason: 'revertido');

      final created = await c
          .read(feedControllerProvider.notifier)
          .publish(texto: 'Nuevo', tipo: PostTipo.logro);
      expect(c.read(feedControllerProvider).value!.posts.first.id, created.id);
      expect(api.last('create_post').params['p_id'], '01900000-0000-7000-8000-000000000001');
      expect(api.last('create_post').params['p_media'], isEmpty);

      final before = shown(p1).comentariosCount;
      c.read(postOverridesProvider.notifier).commentAdded(p1);
      expect(shown(p1).comentariosCount, before + 1);

      await c.read(postOverridesProvider.notifier).delete(created);
      expect(
        c.read(postOverridesProvider).resolve(created),
        isNull,
        reason: 'oculta en todas partes',
      );
    });

    test('loadMore con error: no relanza y no entra en bucle de reintentos', () async {
      var calls = 0;
      final api = FakeApiClient({
        'get_feed': (p) {
          if (p['p_cursor'] == null) {
            return {
              'items': [postJson(id: 'p1')],
              'next_cursor': 'c2',
            };
          }
          calls++;
          throw const NetworkFailure();
        },
      });
      final c = container(api);
      await c.read(feedControllerProvider.future);
      await c.read(feedControllerProvider.notifier).loadMore();
      await c.read(feedControllerProvider.notifier).loadMore();
      await c.read(feedControllerProvider.notifier).loadMore();
      expect(calls, 1, reason: 'pausa tras el fallo');
      expect(c.read(feedControllerProvider).value!.loadingMore, isFalse);
    });

    test('toques repetidos en Recomendar mientras hay una petición en curso: una sola', () async {
      final api = FakeApiClient({
        'get_feed': (_) => {
          'items': [postJson(id: 'p1')],
          'next_cursor': null,
        },
        'recommend': (_) => {'recomendado': true, 'recomendaciones_count': 1},
      });
      final c = container(api);
      final p1 = (await c.read(feedControllerProvider.future)).posts.single;
      final n = c.read(postOverridesProvider.notifier);
      await Future.wait([n.toggleRecommend(p1), n.toggleRecommend(p1)]);
      expect(api.calls.where((x) => x.name == 'recommend'), hasLength(1));
    });

    test('sugerencias (seguir optimista) y cifras', () async {
      final c = container(
        FakeApiClient({
          'suggestions': (_) => [cardJson(id: 'u-9')],
          'follow': (_) => {'is_following': true, 'seguidores_count': 1},
          'community_stats': (_) => {
            'alumni': 6340,
            'activos': 5120,
            'paises': 82,
            'promociones': 51,
          },
          'get_news': (p) => {
            'items': [postJson(id: 'n1', tipo: 'novedad_oficial')],
            'next_cursor': p['p_cursor'] == null ? 'x' : null,
          },
        }),
      );
      final list = await c.read(suggestionsProvider.future);
      await c.read(suggestionsProvider.notifier).toggleFollow(list.single);
      expect(c.read(suggestionsProvider).value!.single.isFollowing, isTrue);
      c.read(suggestionsProvider.notifier).dismiss(list.single);
      expect(c.read(suggestionsProvider).value, isEmpty);
      expect((await c.read(communityStatsProvider.future)).alumni, 6340);
      await c.read(newsControllerProvider.future);
      await c.read(newsControllerProvider.notifier).loadMore();
      expect(c.read(newsControllerProvider).value!.posts, hasLength(2));
    });

    test('Novedades: un fallo al paginar no deja la lista bloqueada', () async {
      var fail = true;
      final c = container(
        FakeApiClient({
          'get_news': (p) {
            if (p['p_cursor'] == null) {
              return {
                'items': [postJson(id: 'n1', tipo: 'novedad_oficial')],
                'next_cursor': 'x',
              };
            }
            if (fail) throw const NetworkFailure();
            return {
              'items': [postJson(id: 'n2', tipo: 'novedad_oficial')],
              'next_cursor': null,
            };
          },
        }),
      );
      await c.read(newsControllerProvider.future);
      await c.read(newsControllerProvider.notifier).loadMore();
      expect(c.read(newsControllerProvider).value!.loadingMore, isFalse);
      fail = false;
      expect(c.read(newsControllerProvider).value!.hasMore, isTrue);
    });
  });

  test('DirectoryController: filtros, paginación y seguir optimista', () async {
    final api = FakeApiClient({
      'search_directory': (p) => {
        'items': p['p_cursor'] == null
            ? [cardJson(id: 'a'), cardJson(id: 'b')]
            : [cardJson(id: 'c')],
        'total': 3,
        'next_cursor': p['p_cursor'] == null ? 'x' : null,
      },
      'follow': (_) => {'is_following': true, 'seguidores_count': 5},
    });
    final c = container(api);
    final sub = c.listen(directoryControllerProvider, (_, _) {});
    addTearDown(sub.close);
    await settle();
    expect(c.read(directoryControllerProvider).items, hasLength(2));
    await c.read(directoryControllerProvider.notifier).loadMore();
    expect(c.read(directoryControllerProvider).items, hasLength(3));

    c.read(directoryControllerProvider.notifier)
      ..setTab(DirectoryTab.miPromocion)
      ..setFase(Fase.fase2)
      ..setPromocion(49);
    await settle();
    expect(api.last('search_directory').params['p_tab'], 'mi_promocion');
    expect(api.last('search_directory').params['p_fase'], 'fase_2');
    expect(api.last('search_directory').params['p_promocion'], 49);

    c.read(directoryControllerProvider.notifier).setQuery('sener');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(api.last('search_directory').params['p_query'], 'sener');

    final first = c.read(directoryControllerProvider).items.first;
    await c.read(directoryControllerProvider.notifier).toggleFollow(first);
    expect(c.read(directoryControllerProvider).items.first.isFollowing, isTrue);
    expect(c.read(directoryControllerProvider).items.first.seguidoresCount, 5);
  });

  group('Chat', () {
    test('mergeMessages: orden por UUIDv7, sin duplicados, el confirmado gana', () {
      Message m(String id, [DeliveryStatus s = DeliveryStatus.enviado]) =>
          Message.fromJson(messageJson(id)).withStatus(s);
      final merged = mergeMessages([m('03'), m('01')], [m('02'), m('03', DeliveryStatus.enviando)]);
      expect(merged.map((x) => x.id), ['01', '02', '03']);
      expect(merged.last.status, DeliveryStatus.enviado);
    });

    test('ChatState.statusOf: enviando → enviado → leído (doble check)', () {
      final other = ProfileCard.fromJson(cardJson(id: 'u-2'));
      final s = ChatState(
        other: other,
        messages: const [],
        categoria: Categoria.networking,
        otherLastReadId: '05',
      );
      Message m(String id, DeliveryStatus st) => Message.fromJson(messageJson(id)).withStatus(st);
      expect(s.statusOf(m('04', DeliveryStatus.enviado)), DeliveryStatus.leido);
      expect(s.statusOf(m('06', DeliveryStatus.enviado)), DeliveryStatus.enviado);
      expect(s.statusOf(m('07', DeliveryStatus.enviando)), DeliveryStatus.enviando);
      expect(s.statusOf(m('08', DeliveryStatus.error)), DeliveryStatus.error);
      expect(s.isNew, isTrue);
    });

    test('nueva conversación por deep link → envío → Realtime → leído', () async {
      final rt = FakeRealtime();
      final auth = FakeAuthGateway(currentUserId: 'me');
      final api = FakeApiClient({
        'me': (_) => meJson(id: 'me'),
        'get_profile': (_) =>
            cardJson(id: '01900000-0000-7000-8000-0000000000b2', nombre: 'Javier'),
        'find_direct_conversation': (_) => null,
        'send_message': (p) => {
          ...messageJson(
            p['p_id'] as String,
            conv: 'c-9',
            from: 'me',
            cuerpo: p['p_cuerpo'] as String,
          ),
          'duplicado': false,
        },
        'list_conversations': (_) => {'items': <Object>[]},
        'unread_counts': (_) => {'mensajes': 0, 'notificaciones': 0},
        'mark_read': (_) => null,
        'set_conversation_category': (_) => null,
      });
      final c = container(api, auth: auth, rt: rt)..read(sessionControllerProvider);
      await settle();
      final p = chatControllerProvider(toUserId: '01900000-0000-7000-8000-0000000000b2');
      final sub = c.listen(p, (_, _) {});
      addTearDown(sub.close);
      final s = await c.read(p.future);
      expect(s.isNew, isTrue);
      expect(s.other.nombre, 'Javier');

      await c.read(p.notifier).setCategory(Categoria.oportunidadLaboral);
      await c.read(p.notifier).send('Hola Javier');
      final after = c.read(p).value!;
      expect(after.conversationId, 'c-9');
      expect(after.messages.single.status, DeliveryStatus.enviado);
      expect(api.last('send_message').params['p_categoria'], 'oportunidad_laboral');
      expect(api.last('send_message').params['p_to'], '01900000-0000-7000-8000-0000000000b2');

      // Llega respuesta por Realtime y la otra persona marca leído
      rt.conversations['c-9']!.add(
        MessageCreated(
          Message.fromJson(messageJson('01900000-0000-7000-8000-0000000000ff', conv: 'c-9')),
        ),
      );
      await settle();
      expect(c.read(p).value!.messages, hasLength(2));
      // «Marcar leído» se agrupa por ráfagas (realtimeBurstWindow, 400 ms).
      await Future<void>.delayed(realtimeBurstWindow + const Duration(milliseconds: 50));
      expect(api.calls.any((x) => x.name == 'mark_read'), isTrue);
      rt.conversations['c-9']!.add(
        const MessageRead(userId: 'u-2', messageId: '01900000-0000-7000-8000-000000000001'),
      );
      await settle();
      final mine = c.read(p).value!.messages.first;
      expect(c.read(p).value!.statusOf(mine), DeliveryStatus.leido);
    });
  });
}
