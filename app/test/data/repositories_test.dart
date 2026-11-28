import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/core/errors/failure.dart';
import 'package:icex_atlas/features/directory/data/directory_repository.dart';
import 'package:icex_atlas/features/feed/data/feed_repository.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/map/data/map_repository.dart';
import 'package:icex_atlas/features/messaging/data/messaging_repository.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';
import 'package:icex_atlas/features/notifications/data/notifications_repository.dart';
import 'package:icex_atlas/features/notifications/domain/app_notification.dart';
import 'package:icex_atlas/features/orientador/data/orientador_repository.dart';
import 'package:icex_atlas/features/orientador/domain/orientador.dart';
import 'package:icex_atlas/features/profiles/data/profiles_repository.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/features/settings/data/account_repository.dart';
import 'package:icex_atlas/features/social/data/social_repository.dart';

import '../helpers/fakes.dart';

void main() {
  group('ProfilesRepository', () {
    test('me, perfil por slug, edición y privacidad', () async {
      final api = FakeApiClient({
        'me': (_) => meJson(),
        'get_profile': (p) => {...cardJson(), 'is_self': false, 'experiences': <Object>[]},
        'update_my_profile': (p) => {...cardJson(), 'cargo': p['p_cargo']},
        'set_privacy': (p) => {...cardJson(), 'visibilidad': p['p_visibilidad']},
        'upsert_experience': (p) => cardJson(),
        'delete_experience': (_) => null,
        'list_follows': (_) => {
          'items': [cardJson()],
          'next_cursor': null,
        },
        'media-upload': (p) => {'path': 'u-1/foto.jpg'},
      });
      final repo = ProfilesRepository(api);
      expect((await repo.me()).userId, 'u-1');
      await repo.getProfile(slug: 'ana');
      expect(api.last('get_profile').params, {'p_slug': 'ana', 'p_user': null});

      final upd = await repo.updateMyProfile(
        const ProfileUpdate(cargo: 'Export Manager', fase: Fase.fase2, lat: 1, lng: 2),
      );
      expect(upd.card.cargo, 'Export Manager');
      expect(api.last('update_my_profile').params, {
        'p_cargo': 'Export Manager',
        'p_fase': 'fase_2',
        'p_lat': 1.0,
        'p_lng': 2.0,
      });

      final priv = await repo.setPrivacy(
        visibilidad: {'bio': Visibilidad.soloYo},
        aceptaSugerencias: false,
      );
      expect(priv.visibilidad['bio'], Visibilidad.soloYo);
      expect(api.last('set_privacy').params['p_acepta_sugerencias'], isFalse);

      await repo.upsertExperience(
        id: 'e1',
        empresa: 'ACS',
        cargo: 'BDM',
        desde: DateTime(2020, 3, 5),
        hasta: DateTime(2022),
      );
      expect(api.last('upsert_experience').params['p_desde'], '2020-03-05');
      expect(api.last('upsert_experience').params['p_hasta'], '2022-01-01');
      await repo.deleteExperience('e1');
      expect((await repo.listFollows('u-1', following: true)).items, hasLength(1));
      expect(api.last('list_follows').params['p_direction'], 'siguiendo');

      await repo.uploadAvatar(Uint8List.fromList([0xff, 0xd8, 0xff]));
      expect(api.last('media-upload').params['query'], {'bucket': 'avatars'});
      expect(api.last('update_my_profile').params, {'p_foto_path': 'u-1/foto.jpg'});
    });
  });

  test('SocialRepository: seguir, bloquear, sugerencias, cifras y denuncias', () async {
    final api = FakeApiClient({
      'follow': (_) => {'is_following': true, 'seguidores_count': 10},
      'unfollow': (_) => {'is_following': false, 'seguidores_count': 9},
      'block': (_) => null,
      'unblock': (_) => null,
      'list_blocked': (_) => [cardJson()],
      'suggestions': (_) => [cardJson(), cardJson(id: 'u-3')],
      'community_stats': (_) => {'alumni': 640, 'activos': 400, 'paises': 30, 'promociones': 51},
      'report': (_) => 'r1',
    });
    final repo = SocialRepository(api);
    expect((await repo.follow('u-2')).seguidoresCount, 10);
    expect((await repo.unfollow('u-2')).isFollowing, isFalse);
    await repo.block('u-2');
    await repo.unblock('u-2');
    expect(await repo.blocked(), hasLength(1));
    expect(await repo.suggestions(limit: 2), hasLength(2));
    expect(api.last('suggestions').params['p_limit'], 2);
    expect((await repo.communityStats()).promociones, 51);
    await repo.report(ReportTarget.post, 'p1', ReportMotivo.contenidoInapropiado, detalle: 'x');
    expect(api.last('report').params, {
      'p_target_tipo': 'post',
      'p_target_id': 'p1',
      'p_motivo': 'contenido_inapropiado',
      'p_detalle': 'x',
    });
    for (final m in ReportMotivo.values) {
      await repo.report(ReportTarget.perfil, 'u', m);
    }
    expect(api.calls.where((c) => c.name == 'report'), hasLength(7));
  });

  group('DirectoryRepository y DirectoryFilter', () {
    test('parámetros de búsqueda y paginación', () async {
      final api = FakeApiClient({
        'search_directory': (_) => {
          'items': [cardJson()],
          'total': 640,
          'next_cursor': 'Ana\u001fu-1',
        },
      });
      const f = DirectoryFilter(
        query: '  sener ',
        promocion: 42,
        fase: Fase.activo,
        tab: DirectoryTab.exterior,
      );
      final page = await DirectoryRepository(api).search(f, cursor: 'c');
      expect(page.total, 640);
      expect(api.last('search_directory').params, {
        'p_query': 'sener',
        'p_promocion': 42,
        'p_fase': 'activo',
        'p_tab': 'exterior',
        'p_cursor': 'c',
        'p_limit': DirectoryRepository.pageSize,
      });
      expect(const DirectoryFilter().toParams()['p_query'], isNull);
    });

    test('copyWith, withTab e igualdad', () {
      const f = DirectoryFilter(query: 'a', promocion: 3, fase: Fase.fase1);
      expect(f.copyWith(promocion: () => null).promocion, isNull);
      expect(f.copyWith(fase: () => Fase.fase2).fase, Fase.fase2);
      expect(f.copyWith(query: 'b').query, 'b');
      final t = f.withTab(DirectoryTab.activo);
      expect(t.promocion, isNull);
      expect(t.query, 'a');
      expect(f, const DirectoryFilter(query: 'a', promocion: 3, fase: Fase.fase1));
      expect(
        f.hashCode,
        const DirectoryFilter(query: 'a', promocion: 3, fase: Fase.fase1).hashCode,
      );
      expect(f == t, isFalse);
    });
  });

  test('FeedRepository', () async {
    final api = FakeApiClient({
      'get_feed': (_) => {
        'items': [postJson()],
        'destacadas': <Object>[],
        'next_cursor': 'n',
      },
      'get_news': (_) => {
        'items': [postJson(tipo: 'novedad_oficial')],
      },
      'get_user_posts': (_) => {
        'items': [postJson()],
      },
      'get_post': (_) => postJson(),
      'create_post': (p) => postJson(id: p['p_id'] as String),
      'delete_post': (_) => null,
      'recommend': (_) => {'recomendado': true, 'recomendaciones_count': 77},
      'unrecommend': (_) => {'recomendado': false, 'recomendaciones_count': 76},
      'get_comments': (_) => {'items': <Object>[]},
      'add_comment': (p) => {
        'id': p['p_id'],
        'post_id': p['p_post'],
        'texto': p['p_texto'],
        'created_at': '2026-11-16T10:00:00Z',
        'autor': cardJson(),
      },
      'delete_comment': (_) => null,
      'media-upload': (_) => {'path': 'u-1/img.jpg'},
    });
    final repo = FeedRepository(api);
    expect((await repo.feed(cursor: 'x')).hasMore, isTrue);
    expect(api.last('get_feed').params, {'p_cursor': 'x', 'p_limit': 20});
    expect((await repo.news()).items.single.tipo, PostTipo.novedadOficial);
    expect((await repo.userPosts('u-2')).items, hasLength(1));
    expect((await repo.post('p-1')).id, 'p-1');
    final created = await repo.create(
      id: 'id-1',
      texto: 'Hola',
      tipo: PostTipo.logro,
      media: ['u-1/img.jpg'],
    );
    expect(created.id, 'id-1');
    expect(api.last('create_post').params['p_tipo'], 'logro');
    await repo.delete('id-1');
    expect((await repo.setRecommended('p-1', value: true)).count, 77);
    expect((await repo.setRecommended('p-1', value: false)).recomendado, isFalse);
    expect((await repo.comments('p-1')).items, isEmpty);
    expect((await repo.addComment(id: 'c1', postId: 'p-1', texto: 'Bien')).texto, 'Bien');
    await repo.deleteComment('c1');
    expect(await repo.uploadImage(Uint8List(3)), 'u-1/img.jpg');
    expect(api.last('media-upload').params['query'], {'bucket': 'post-media'});
  });

  test('MessagingRepository', () async {
    final api = FakeApiClient({
      'list_conversations': (_) => {
        'items': [
          {'id': 'c1', 'categoria': 'evento', 'no_leidos': 1, 'otro': cardJson()},
        ],
        'next_cursor': null,
      },
      'unread_counts': (_) => {'mensajes': 6, 'notificaciones': 2},
      'get_conversation': (_) => {'id': 'c1', 'categoria': 'evento', 'otro': cardJson()},
      'find_direct_conversation': (_) => 'c1',
      'get_messages': (_) => {
        'items': [messageJson('m1')],
        'has_more': true,
      },
      'send_message': (p) => {...messageJson(p['p_id'] as String, from: 'u-1'), 'duplicado': false},
      'mark_read': (_) => null,
      'set_conversation_category': (_) => null,
      'heartbeat': (_) => null,
    });
    final repo = MessagingRepository(api);
    expect((await repo.conversations(categoria: Categoria.evento)).items.single.noLeidos, 1);
    expect(api.last('list_conversations').params['p_categoria'], 'evento');
    expect(await repo.totalUnread(), 6);
    expect((await repo.conversation('c1')).categoria, Categoria.evento);
    expect(await repo.findDirect('u-2'), 'c1');
    final b = await repo.messages('c1', after: 'm0');
    expect(b.hasMore, isTrue);
    expect(api.last('get_messages').params['p_after'], 'm0');
    final s = await repo.send(
      id: 'm2',
      cuerpo: 'Hola',
      toUserId: 'u-2',
      categoria: Categoria.mentoria,
    );
    expect(s.duplicate, isFalse);
    expect(api.last('send_message').params['p_categoria'], 'mentoria');
    await repo.markRead('c1', 'm2');
    await repo.setCategory('c1', Categoria.networking);
    await repo.heartbeat();
    expect(
      api.calls.map((c) => c.name),
      containsAll(['mark_read', 'set_conversation_category', 'heartbeat']),
    );
  });

  test('NotificationsRepository', () async {
    final api = FakeApiClient({
      'list_notifications': (_) => {
        'items': [
          {'id': 'n1', 'tipo': 'comentario', 'created_at': '2026-11-16T10:00:00Z'},
        ],
        'no_leidas': 4,
      },
      'mark_notifications_read': (_) => 4,
      'unread_counts': (_) => {'mensajes': 1, 'notificaciones': 4},
      'get_notification_preferences': (_) => {'push_mensajes': false},
      'update_notification_preferences': (p) => p['p_prefs'],
      'register_push_token': (_) => null,
      'unregister_push_token': (_) => null,
    });
    final repo = NotificationsRepository(api);
    expect((await repo.list()).unread, 4);
    expect(await repo.markRead(['n1']), 4);
    expect((await repo.unreadCounts()).notificaciones, 4);
    expect((await repo.preferences()).pushMensajes, isFalse);
    expect(
      (await repo.updatePreferences(const NotificationPreferences(pushEventos: false))).pushEventos,
      isFalse,
    );
    await repo.registerPushToken('tok', platform: 'android');
    expect(api.last('register_push_token').params, {'p_token': 'tok', 'p_plataforma': 'android'});
    await repo.unregisterPushToken('tok');
  });

  test('MapRepository y ClubsRepository', () async {
    final club = {'id': 'k1', 'nombre': 'Club Alumni Madrid', 'lat': 40.4, 'lng': -3.7};
    final event = {
      'id': 'e1',
      'club_id': 'k1',
      'titulo': 'Café',
      'inicio': '2026-11-20T18:00:00Z',
      'mi_inscripcion': 'inscrito',
    };
    final api = FakeApiClient({
      'map_clusters': (_) => {
        'clusters': <Object>[],
        'clubs': [club],
        'total': 0,
      },
      'alumni_near': (_) => [cardJson()],
      'list_clubs': (_) => [club],
      'get_club': (_) => club,
      'join_club': (_) => {...club, 'mi_rol': 'miembro'},
      'leave_club': (_) => club,
      'list_events': (_) => [event],
      'register_event': (_) => event,
      'cancel_event_registration': (_) => {...event, 'mi_inscripcion': null},
    });
    final map = MapRepository(api);
    const b = Bounds(west: -10, south: 35, east: 5, north: 45);
    await map.clusters(zoom: 5, bounds: b, fases: {Fase.activo}, includeClubs: false);
    expect(api.last('map_clusters').params['p_fases'], ['activo']);
    expect(api.last('map_clusters').params['p_include_clubs'], isFalse);
    await map.clusters(zoom: 5, bounds: b, fases: Fase.values.toSet());
    expect(
      api.last('map_clusters').params['p_fases'],
      isNull,
      reason: 'todas las fases = sin filtro',
    );
    expect(await map.alumniNear(40, -3), hasLength(1));

    final clubs = ClubsRepository(api);
    expect(await clubs.list(query: 'mad'), hasLength(1));
    expect((await clubs.get('k1')).nombre, 'Club Alumni Madrid');
    expect((await clubs.join('k1')).isMember, isTrue);
    expect((await clubs.leave('k1')).isMember, isFalse);
    expect(await clubs.events(clubId: 'k1'), hasLength(1));
    expect((await clubs.register('e1')).titulo, 'Café');
    await clubs.cancel('e1');
  });

  test('OrientadorRepository usa la Edge Function', () async {
    final api = FakeApiClient({
      'orientador': (p) => {
        'resumen': 'r',
        'pasos': ['1'],
        'alumni': <Object>[],
        'aviso': 'a',
        'restantes': 3,
      },
    });
    const q = OrientadorQuery(
      fase: Fase.fase2,
      pais: 'Perú',
      sector: 'Banca',
      consulta: '¿Primer empleo?',
    );
    final r = await OrientadorRepository(api).ask(q);
    expect(r.restantes, 3);
    expect(api.last('orientador').params['body'], q.toJson());
  });

  test('AccountRepository: exportación y borrado con confirmación', () async {
    final api = FakeApiClient({
      'export_my_data': (_) => {
        'perfil': {'nombre': 'Ana'},
      },
      'account-delete': (_) => {'ok': true},
    });
    final repo = AccountRepository(api);
    expect(await repo.exportData(), contains('"nombre": "Ana"'));
    expect(() => repo.deleteAccount('borrar'), throwsArgumentError);
    await repo.deleteAccount(' BORRAR MI CUENTA ');
    expect(api.last('account-delete').params['body'], {'confirmacion': 'BORRAR MI CUENTA'});
  });

  test('AppFailure.fromCode traduce códigos de la API', () {
    expect(AppFailure.fromCode('42501', 'x'), isA<ForbiddenFailure>());
    expect(AppFailure.fromCode('403', null), isA<ForbiddenFailure>());
    expect(AppFailure.fromCode('P0002', 'x'), isA<NotFoundFailure>());
    expect(
      AppFailure.fromCode('23503', 'x'),
      isA<NotFoundFailure>(),
      reason: 'borrado a la vez por otro',
    );
    expect(AppFailure.fromCode('P0001', 'x', hint: 'rate_limited'), isA<RateLimitedFailure>());
    expect(AppFailure.fromCode('429', 'x'), isA<RateLimitedFailure>());
    expect(AppFailure.fromCode('P0001', 'x'), isA<UnknownFailure>());
    expect(AppFailure.fromCode('22023', 'x'), isA<ValidationFailure>());
    expect(AppFailure.fromCode('415', 'x'), isA<ValidationFailure>());
    expect(AppFailure.fromCode(null, null), isA<UnknownFailure>());
    expect(const NetworkFailure().toString(), 'AppFailure(Sin conexión)');
  });
}
