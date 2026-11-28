import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/core/db/app_database.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/features/profiles/domain/profile_completion.dart';

import '../helpers/app_harness.dart';
import '../helpers/fakes.dart';

/// El scroll vertical de Inicio (el carrusel de sugerencias también es Scrollable).
final Finder _feedScroll = find
    .descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable))
    .first;

void main() {
  group('Feed en frío', () {
    testWidgets('sin seguir a nadie: bienvenida, sugerencias y destacado en la comunidad', (
      t,
    ) async {
      final api = coldApi();
      await pumpApp(t, appHarness(api));
      expect(find.byKey(const Key('cold-start-intro')), findsOneWidget);
      expect(find.text('Sigue a otros alumni para ver aquí sus publicaciones.'), findsNothing);
      expect(find.text('Personas que quizá conozcas'), findsOneWidget);
      await t.scrollUntilVisible(
        find.byKey(const Key('highlights-header')),
        300,
        scrollable: _feedScroll,
      );
      expect(find.text('Destacado en la comunidad'), findsOneWidget);
      await t.scrollUntilVisible(
        find.text('Publicación destacada de Carmen Destacada'),
        300,
        scrollable: _feedScroll,
      );
      expect(api.calls.where((c) => c.name == 'community_highlights'), isNotEmpty);
    });

    testWidgets('sin nada destacado, se mantiene el estado vacío de siempre', (t) async {
      final api = coldApi()..responders['community_highlights'] = (_) => <Object>[];
      await pumpApp(t, appHarness(api));
      expect(find.text('Sigue a otros alumni para ver aquí sus publicaciones.'), findsOneWidget);
      expect(find.byKey(const Key('highlights-header')), findsNothing);
    });

    testWidgets('feed corto: lo destacado va debajo y sin repetir publicaciones', (t) async {
      final api = coldApi(posts: 2);
      await pumpApp(t, appHarness(api));
      expect(find.byKey(const Key('cold-start-intro')), findsNothing);
      await t.scrollUntilVisible(
        find.byKey(const Key('highlights-header')),
        300,
        scrollable: _feedScroll,
      );
      await t.scrollUntilVisible(
        find.text('Publicación destacada de Pablo Destacado'),
        300,
        scrollable: _feedScroll,
      );
      expect(find.byKey(const ValueKey('hl-p0')), findsNothing);
    });

    testWidgets('feed con contenido: no se pide lo destacado', (t) async {
      final api = fullDemoApi()..responders['community_highlights'] = (_) => <Object>[];
      await pumpApp(t, appHarness(api));
      expect(api.calls.where((c) => c.name == 'community_highlights'), isEmpty);
      expect(find.byKey(const Key('highlights-header')), findsNothing);
    });

    testWidgets('si falla, el feed sigue funcionando', (t) async {
      final api = coldApi(posts: 2)
        ..responders['community_highlights'] = (_) => throw Exception('caído');
      await pumpApp(t, appHarness(api));
      expect(find.byKey(const Key('highlights-header')), findsNothing);
      expect(find.byKey(const ValueKey('p0')), findsOneWidget);
    });
  });

  group('Completa tu perfil', () {
    test('cuenta lo que falta, en orden de importancia', () {
      final empty = ProfileCompletion.of(Me.fromJson(newcomerMe()).profile);
      expect(empty.percent, 0);
      expect(empty.missing.first, ProfileItem.photo);
      expect(empty.worthNudgingOnHome, isTrue);
      final ana = ProfileCompletion.of(Me.fromJson(meJson()).profile);
      expect(ana.missing, [ProfileItem.photo, ProfileItem.experience]);
      expect(ana.percent, 67);
      expect(ana.worthNudgingOnHome, isFalse);
    });

    testWidgets('a quien le falta lo básico se le avisa en Inicio y puede descartarlo', (t) async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await pumpApp(t, appHarness(coldApi(), db: db));
      expect(find.byKey(const Key('profile-completion')), findsOneWidget);
      expect(find.text('Tu perfil está al 0 %'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Foto'), findsOneWidget);
      await t.tap(find.byKey(const Key('profile-completion-dismiss')));
      await settleData(t);
      expect(find.byKey(const Key('profile-completion')), findsNothing);
      expect(await db.select(db.cachedPages).get(), isNotEmpty, reason: 'el descarte se recuerda');

      // Al volver a abrir la app con el mismo dispositivo, no vuelve a salir.
      await t.pumpWidget(const SizedBox());
      await pumpApp(t, appHarness(coldApi(), db: db));
      expect(find.byKey(const Key('profile-completion')), findsNothing);
    });

    testWidgets('tocar lo que falta abre la edición del perfil', (t) async {
      await pumpApp(t, appHarness(coldApi()));
      await t.tap(find.widgetWithText(ActionChip, 'Sobre ti'));
      await settleData(t);
      expect(find.byKey(const Key('edit-promo')), findsOneWidget);
    });

    testWidgets('un perfil casi completo no molesta en Inicio', (t) async {
      await pumpApp(t, appHarness(fullDemoApi()));
      expect(find.byKey(const Key('profile-completion')), findsNothing);
    });

    testWidgets('en el perfil propio se ve siempre que falte algo (sin descartar)', (t) async {
      final api = fullDemoApi()
        ..responders['get_profile'] = (_) => {
          ...meJson()['profile'] as Map<String, dynamic>,
          'is_self': true,
        };
      await pumpApp(t, appHarness(api), location: '/perfil/ana');
      expect(find.byKey(const Key('profile-completion')), findsOneWidget);
      expect(find.text('Tu perfil está al 67 %'), findsOneWidget);
      expect(find.byKey(const Key('profile-completion-dismiss')), findsNothing);
    });
  });
}
