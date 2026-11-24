import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:icex_atlas/core/config/app_env.dart';
import 'package:icex_atlas/core/db/app_database.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/router/app_router.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';

import 'fakes.dart';

/// Arnés de la APP COMPLETA (router, barra superior, navegación inferior y tema reales)
/// sobre un backend falso con datos de demostración. Lo usan los tests de rendimiento,
/// de diseño en distintos tamaños, de accesibilidad y las capturas.

/// Tamaños de pantalla representativos (puntos lógicos).
abstract final class Screens {
  static const small = Size(320, 568); // iPhone SE (1.ª gen.), Android pequeño
  static const phone = Size(390, 844); // iPhone 14/15
  static const android = Size(412, 915); // Pixel 7
  static const tablet = Size(800, 1280);
  static const Map<String, Size> all = {
    'pequeño': small,
    'iPhone': phone,
    'Android': android,
    'tablet': tablet,
  };
}

String _ago(int minutes) =>
    DateTime.now().toUtc().subtract(Duration(minutes: minutes)).toIso8601String();

const longText =
    'Después de tres años en Singapur, vuelvo a Madrid para incorporarme al equipo de '
    'desarrollo internacional. Quiero dar las gracias a todas las personas de la 42ª '
    'promoción que me ayudaron a preparar la Fase II: las entrevistas simuladas, los '
    'consejos sobre cómo presentar el proyecto y, sobre todo, las conversaciones a las tantas '
    'cuando no sabía si iba a salir bien. Si alguien está preparando su destino en el '
    'sudeste asiático, escribidme: os cuento lo que me habría gustado saber antes de '
    'llegar, desde la vivienda hasta cómo funcionan las cámaras de comercio de la zona.';

/// Backend falso con respuestas para todas las pantallas principales.
FakeApiClient fullDemoApi({int posts = 6}) => FakeApiClient({
  'me': (_) => meJson(),
  'get_feed': (_) => {
    'items': [
      for (var i = 0; i < posts; i++)
        {
          ...postJson(
            id: 'p$i',
            createdAt: _ago(15 + i * 40),
            tipo: i == 1 ? 'oportunidad_laboral' : (i == 3 ? 'evento' : 'general'),
            autor: cardJson(
              id: 'u-${i + 2}',
              nombre: ['Javier Martín Jiménez', 'Inés Domínguez Gil', 'Laura Gil Navarro'][i % 3],
              promocion: 40 + i,
            ),
          ),
          if (i == 0) 'texto': longText,
        },
    ],
    'destacadas': [
      {
        ...postJson(id: 'n1', tipo: 'novedad_oficial'),
        'titulo': 'Reunión Anual ICEX Alumni 2026',
        'texto': 'Sede de ICEX en Madrid y en streaming.',
      },
    ],
    'next_cursor': null,
  },
  'get_news': (_) => {'items': <Object>[], 'next_cursor': null},
  'community_stats': (_) => {'alumni': 6340, 'activos': 5120, 'paises': 82, 'promociones': 51},
  'suggestions': (_) => [
    for (var i = 0; i < 4; i++)
      cardJson(id: 'u-s$i', nombre: 'Persona Sugerida $i', promocion: 30 + i, empresa: 'Cepsa'),
  ],
  'search_directory': (_) => {
    'items': [
      for (var i = 0; i < 12; i++)
        cardJson(id: 'u-d$i', nombre: 'Alumni Directorio Número $i', promocion: 20 + i),
    ],
    'total': 640,
    'next_cursor': 'x',
  },
  'unread_counts': (_) => {'mensajes': 3, 'notificaciones': 2},
  'list_conversations': (_) => {
    'items': [
      for (var i = 0; i < 6; i++)
        {
          'id': 'c$i',
          'categoria': ['mentoria', 'networking', 'evento'][i % 3],
          'no_leidos': i == 0 ? 2 : 0,
          'ultimo_mensaje_en': _ago(5 + i * 300),
          'ultimo_mensaje_preview': 'La primera semana es intensa pero merece la pena',
          'otro': cardJson(id: 'u-c$i', nombre: 'Contacto Número $i'),
        },
    ],
    'next_cursor': null,
  },
  'get_conversation': (_) => {'id': 'c0', 'categoria': 'mentoria', 'otro': cardJson(id: 'u-2')},
  'get_messages': (_) => {
    'items': [
      for (var i = 0; i < 8; i++)
        {
          ...messageJson(
            '01900000-0000-7000-8000-0000000001${i.toString().padLeft(2, '0')}',
            conv: 'c0',
            from: i.isEven ? 'u-2' : 'u-1',
            cuerpo: 'Mensaje $i de la conversación',
          ),
          'created_at': _ago(60 - i),
        },
    ],
    'has_more': false,
  },
  'mark_read': (_) => null,
  'heartbeat': (_) => null,
  'get_profile': (_) => {
    ...cardJson(id: 'u-2', nombre: 'Javier Martín Jiménez', promocion: 42),
    'bio': longText,
    'posts_count': 12,
    'follows_me': true,
    'experiences': [
      {'id': 'e1', 'empresa': 'Sener', 'cargo': 'Export Manager', 'desde': '2021-01-01'},
    ],
  },
  'get_user_posts': (_) => {
    'items': [postJson(id: 'pu1')],
    'next_cursor': null,
  },
  'list_notifications': (_) => {
    'items': [
      {
        'id': 'n1',
        'tipo': 'comentario',
        'created_at': _ago(30),
        'actores': [cardJson(id: 'u-2')],
      },
    ],
    'no_leidas': 1,
  },
  'mark_notifications_read': (_) => 0,
  'get_post': (_) => {...postJson(id: 'p0'), 'texto': longText},
  'get_comments': (_) => {
    'items': [
      {
        'id': 'k1',
        'post_id': 'p0',
        'texto': '¡Enhorabuena! Escríbeme cuando llegues a Madrid.',
        'created_at': _ago(10),
        'autor': cardJson(id: 'u-9', nombre: 'Marta Ruiz Peña'),
      },
    ],
    'next_cursor': null,
  },
  'map_clusters': (_) => {'clusters': <Object>[], 'clubs': <Object>[], 'total': 0},
});

/// La app completa, ya con sesión iniciada como Ana (u-1).
Widget appHarness(FakeApiClient api, {FakeAuthGateway? auth, FakeRealtime? realtime}) {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      authGatewayProvider.overrideWithValue(auth ?? FakeAuthGateway(currentUserId: 'u-1')),
      realtimeGatewayProvider.overrideWithValue(realtime ?? FakeRealtime()),
      appDatabaseProvider.overrideWithValue(db),
      idGeneratorProvider.overrideWithValue(FakeIds()),
      appEnvProvider.overrideWithValue(
        const AppEnv(
          supabaseUrl: 'http://x',
          supabaseAnonKey: 'k',
          oidcProvider: 'custom:icex-alumni',
          authRedirect: 'x://y',
          environment: 'test',
          // Sin teselas de red en los tests.
          mapTileUrl: '',
        ),
      ),
    ],
    child: Consumer(
      builder: (context, ref, _) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: IcexTheme.light(),
        routerConfig: ref.watch(appRouterProvider),
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    ),
  );
}

/// Bombea la app a [size] y [textScale] y espera a que carguen sesión y datos.
Future<void> pumpApp(
  WidgetTester t,
  Widget app, {
  Size size = Screens.phone,
  double textScale = 1,
  String? location,
}) async {
  // Tamaño físico = lógico (dpr 1): así MediaQuery y el layout ven la misma pantalla.
  t.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    t.platformDispatcher.clearTextScaleFactorTestValue();
    t.view.reset();
  });
  await t.pumpWidget(app);
  await settleData(t);
  if (location != null) await goTo(t, location);
}

/// Bombea frames suficientes para que se resuelvan las respuestas encadenadas (sesión →
/// perfil → datos) sin esperar a animaciones infinitas (esqueletos, indicadores).
Future<void> settleData(WidgetTester t, {int frames = 10}) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

/// Navega dentro de la app real.
Future<void> goTo(WidgetTester t, String location) async {
  GoRouter.of(t.element(find.byType(Navigator).first)).go(location);
  await settleData(t);
}
