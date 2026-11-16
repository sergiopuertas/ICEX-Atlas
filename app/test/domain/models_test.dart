import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/core/api/page.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/map/domain/map_models.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';
import 'package:icex_atlas/features/notifications/domain/app_notification.dart';
import 'package:icex_atlas/features/orientador/domain/orientador.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';

import '../helpers/fakes.dart';

void main() {
  group('Fase', () {
    test('parse y etiquetas del mockup', () {
      expect(Fase.parse('fase_0').label, 'Fase 0');
      expect(Fase.parse('fase_1').label, 'Fase I');
      expect(Fase.parse('fase_2').label, 'Fase II');
      expect(Fase.parse('activo').label, 'ACTIVO');
      expect(Fase.parse('desconocida'), Fase.activo);
      expect(Fase.parse(null), Fase.activo);
    });
  });

  group('ProfileCard', () {
    test('fromJson y headline "cargo en empresa"', () {
      final p = ProfileCard.fromJson(cardJson());
      expect(p.headline, 'Business Development Manager en ACS');
      expect(p.location, 'Lima, Perú');
      expect(p.initials, 'AO');
      expect(p.seguidoresCount, 1350);
    });

    test('headline tolera campos ocultos por privacidad', () {
      expect(
        ProfileCard.fromJson(cardJson(empresa: null)).headline,
        'Business Development Manager',
      );
      expect(ProfileCard.fromJson(cardJson(cargo: null)).headline, 'ACS');
      expect(ProfileCard.fromJson(cardJson(cargo: null, empresa: null)).headline, '');
    });

    test('iniciales con nombre de una palabra o vacío', () {
      expect(ProfileCard.fromJson(cardJson(nombre: 'Íñigo')).initials, 'Í');
      expect(ProfileCard.fromJson(cardJson(nombre: '  ')).initials, '?');
    });

    test('copyWith', () {
      final p = ProfileCard.fromJson(cardJson()).copyWith(isFollowing: true, seguidoresCount: 2);
      expect(p.isFollowing, isTrue);
      expect(p.seguidoresCount, 2);
      expect(p.nombre, 'Ana Ortega Jiménez');
    });
  });

  test('ProfileDetail y Me', () {
    final me = Me.fromJson({
      ...meJson(role: 'admin'),
      'profile': {
        ...cardJson(),
        'bio': 'Hola',
        'posts_count': 3,
        'is_self': true,
        'follows_me': true,
        'visibilidad': {'empresa': 'seguidores', 'bio': 'solo_yo'},
        'acepta_sugerencias': false,
        'experiences': [
          {'id': 'e1', 'empresa': 'ACS', 'cargo': 'BDM', 'desde': '2020-01-01', 'hasta': null},
          {
            'id': 'e2',
            'empresa': 'CESCE',
            'cargo': 'Analista',
            'desde': '2018-01-01',
            'hasta': '2019-12-01',
          },
        ],
      },
    });
    expect(me.isAdmin, isTrue);
    expect(me.isModerator, isTrue);
    expect(me.profile.experiences.first.isCurrent, isTrue);
    expect(me.profile.experiences.last.isCurrent, isFalse);
    expect(me.profile.visibilidad['empresa'], Visibilidad.seguidores);
    expect(me.profile.visibilidad['bio'], Visibilidad.soloYo);
    expect(me.profile.aceptaSugerencias, isFalse);
    expect(Visibilidad.parse('x'), Visibilidad.socios);
    expect(Me.fromJson(meJson()).isModerator, isFalse);
  });

  test('CommunityStats', () {
    final s = CommunityStats.fromJson({
      'alumni': 6340,
      'activos': 5120,
      'paises': 82,
      'promociones': 51,
    });
    expect([s.alumni, s.activos, s.paises, s.promociones], [6340, 5120, 82, 51]);
  });

  group('Post', () {
    test('fromJson, badge por tipo y recomendación optimista', () {
      final p = Post.fromJson(postJson(tipo: 'oportunidad_laboral'));
      expect(p.tipo, PostTipo.oportunidadLaboral);
      expect(p.tipo.hasBadge, isTrue);
      expect(PostTipo.general.hasBadge, isFalse);
      final r = p.toggleRecommendation();
      expect(r.recomendado, isTrue);
      expect(r.recomendacionesCount, 77);
      expect(r.toggleRecommendation().recomendacionesCount, 76);
      expect(PostTipo.parse('raro'), PostTipo.general);
      expect(PostTipo.publicables, isNot(contains(PostTipo.novedadOficial)));
    });

    test('publicación compartida y página de feed', () {
      final shared = {
        ...postJson(id: 'p-2'),
        'compartido': {'id': 'p-1', 'texto': 'original', 'autor': cardJson()},
      };
      final page = FeedPage.fromJson({
        'items': [shared],
        'destacadas': [postJson(id: 'n-1', tipo: 'novedad_oficial')],
        'next_cursor': 'abc',
      });
      expect(page.items.single.compartido!.texto, 'original');
      expect(page.destacadas.single.tipo, PostTipo.novedadOficial);
      expect(page.hasMore, isTrue);
      expect(FeedPage.fromJson(const {}).items, isEmpty);
    });

    test('Comment', () {
      final c = Comment.fromJson({
        'id': 'c1',
        'post_id': 'p1',
        'texto': '¡Enhorabuena!',
        'created_at': '2026-11-16T10:00:00Z',
        'autor': cardJson(),
      });
      expect(c.autor.nombre, 'Ana Ortega Jiménez');
    });
  });

  group('Mensajería', () {
    test('Categoria: códigos y etiquetas', () {
      for (final c in Categoria.values) {
        expect(Categoria.parse(c.code), c);
        expect(c.label, isNotEmpty);
      }
      expect(Categoria.parse('x'), Categoria.networking);
      expect(Categoria.oportunidadLaboral.label, 'Oportunidad laboral');
    });

    test('Conversation y doble check por orden de UUIDv7', () {
      final c = Conversation.fromJson({
        'id': 'c1',
        'categoria': 'mentoria',
        'no_leidos': 2,
        'ultimo_mensaje_en': '2026-11-16T10:00:00Z',
        'ultimo_mensaje_preview': '¿Te vendría bien una llamada?',
        'otro': {...cardJson(), 'ultimo_leido_id': '01900000-0000-7000-8000-000000000005'},
      });
      expect(c.categoria, Categoria.mentoria);
      expect(c.isReadByOther('01900000-0000-7000-8000-000000000004'), isTrue);
      expect(c.isReadByOther('01900000-0000-7000-8000-000000000009'), isFalse);
      final m = Message.fromJson(messageJson('m1'));
      expect(m.withStatus(DeliveryStatus.error).status, DeliveryStatus.error);
    });
  });

  test('Notificaciones: tipos, ruta y preferencias', () {
    final n = AppNotification.fromJson({
      'id': 'n1',
      'tipo': 'recomendacion',
      'total': 3,
      'leido': false,
      'updated_at': '2026-11-16T10:00:00Z',
      'actores': [cardJson()],
      'payload': {'post_id': 'p1'},
    });
    expect(n.tipo, NotificationTipo.recomendacion);
    expect(n.route, '/post/p1');
    final f = AppNotification.fromJson({
      'id': 'n2',
      'tipo': 'nuevo_seguidor',
      'created_at': '2026-11-16T10:00:00Z',
      'actores': [cardJson()],
    });
    expect(f.route, '/perfil/ana-ortega-u-1');
    final m = AppNotification.fromJson({
      'id': 'n3',
      'tipo': 'mensaje',
      'created_at': '2026-11-16T10:00:00Z',
      'payload': {'conversation_id': 'c9'},
    });
    expect(m.route, '/mensajes/c9');
    for (final t in ['comentario', 'evento', 'novedad', 'otro']) {
      expect(
        AppNotification.fromJson({'id': 'x', 'tipo': t, 'created_at': '2026-11-16T10:00:00Z'})
            .route,
        '/notificaciones',
      );
    }
    const p = NotificationPreferences(pushSocial: false);
    final json = p.toJson();
    expect(json['push_social'], isFalse);
    expect(NotificationPreferences.fromJson(json).pushSocial, isFalse);
    expect(NotificationPreferences.fromJson(const {}).pushMensajes, isTrue);
  });

  test('Mapa: clusters, clubs y eventos', () {
    final data = MapViewData.fromJson({
      'total': 3,
      'clusters': [
        {'lat': 40.4, 'lng': -3.7, 'count': 2},
        {'lat': -12.0, 'lng': -77.0, 'count': 1, 'alumni': cardJson()},
      ],
      'clubs': [
        {
          'id': 'k1',
          'nombre': 'Club Alumni Madrid',
          'lat': 40.4,
          'lng': -3.7,
          'miembros_count': 80,
          'mi_rol': 'miembro',
        },
      ],
    });
    expect(data.clusters.first.isSingle, isFalse);
    expect(data.clusters.last.isSingle, isTrue);
    expect(data.clubs.single.isMember, isTrue);
    final club = Club.fromJson({
      'id': 'k1',
      'nombre': 'Club',
      'proximos_eventos': [
        {
          'id': 'e1',
          'club_id': 'k1',
          'titulo': 'Café',
          'inicio': '2026-11-20T18:00:00Z',
          'aforo': 1,
          'inscritos_count': 1,
          'mi_inscripcion': 'lista_espera',
        },
        {
          'id': 'e2',
          'club_id': 'k1',
          'titulo': 'Online',
          'inicio': '2026-11-21T18:00:00Z',
          'mi_inscripcion': 'inscrito',
        },
      ],
    });
    expect(club.isMember, isFalse);
    expect(club.proximosEventos.first.isFull, isTrue);
    expect(club.proximosEventos.first.inscripcion, Inscripcion.listaEspera);
    expect(club.proximosEventos.last.inscripcion, Inscripcion.inscrito);
    expect(club.proximosEventos.last.isFull, isFalse);
    expect(MapViewData.empty.total, 0);
  });

  test('Orientador: consulta, resultado y catálogos', () {
    const q = OrientadorQuery(
      fase: Fase.fase1,
      pais: 'Alemania',
      sector: 'Energía',
      consulta: 'Entrevista',
    );
    expect(q.toJson(), {
      'fase': 'fase_1',
      'pais': 'Alemania',
      'sector': 'Energía',
      'consulta': 'Entrevista',
    });
    expect(q.copyWith(pais: 'Perú').pais, 'Perú');
    final r = OrientadorResult.fromJson(q, {
      'resumen': 'r',
      'pasos': ['a', 'b'],
      'alumni': [
        {
          'user_id': 'u',
          'slug': 's',
          'nombre': 'N',
          'motivo': 'm',
          'fase': 'activo',
          'promocion': 30,
        },
      ],
      'aviso': 'aviso',
      'restantes': 9,
    });
    expect(r.pasos, ['a', 'b']);
    expect(r.alumni.single.fase, Fase.activo);
    expect(r.restantes, 9);
    expect(OrientadorCatalog.paises, hasLength(30));
    expect(OrientadorCatalog.sectores, hasLength(10));
    expect(
      OrientadorCatalog.atajos.map((a) => a.$1),
      contains('Preparar la entrevista de Fase II'),
    );
  });

  test('CursorPage.append', () {
    const a = CursorPage<int>(items: [1, 2], nextCursor: 'x', total: 5);
    final b = a.append(const CursorPage(items: [3]));
    expect(b.items, [1, 2, 3]);
    expect(b.hasMore, isFalse);
    expect(b.total, 5);
  });
}
