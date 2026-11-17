import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/core/config/app_env.dart';
import 'package:icex_atlas/core/db/app_database.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/theme/icex_theme.dart';
import 'package:icex_atlas/features/auth/presentation/login_page.dart';
import 'package:icex_atlas/features/directory/presentation/network_page.dart';
import 'package:icex_atlas/features/feed/domain/post.dart';
import 'package:icex_atlas/features/feed/presentation/home_page.dart';
import 'package:icex_atlas/features/feed/presentation/news_page.dart';
import 'package:icex_atlas/features/feed/presentation/post_card.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';
import 'package:icex_atlas/features/messaging/presentation/chat_page.dart';
import 'package:icex_atlas/features/messaging/presentation/conversations_page.dart';
import 'package:icex_atlas/features/orientador/domain/orientador.dart';
import 'package:icex_atlas/features/orientador/presentation/orientador_page.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';

import '../helpers/fakes.dart';

const _phone = Size(400, 860);

/// Fechas relativas a ahora: la antigüedad mostrada («hace 15 min») no depende del día del test.
String _ago(int minutes) =>
    DateTime.now().toUtc().subtract(Duration(minutes: minutes)).toIso8601String();

FakeApiClient demoApi() => FakeApiClient({
  'me': (_) => meJson(),
  'get_feed': (_) => {
    'items': [
      postJson(id: 'p1', createdAt: _ago(15)),
      postJson(
        id: 'p2',
        tipo: 'oportunidad_laboral',
        recomendado: true,
        recos: 153,
        createdAt: _ago(50),
        autor: cardJson(
          id: 'u-3',
          nombre: 'Inés Domínguez Gil',
          promocion: 47,
          cargo: 'Export Manager',
          empresa: 'Mercadona',
        ),
      ),
    ],
    'destacadas': [
      {
        ...postJson(id: 'n1', tipo: 'novedad_oficial'),
        'titulo': 'Reunión Anual ICEX Alumni 2026: El networking en la comunidad de becarios',
        'texto': 'Sede de ICEX en Madrid y en streaming.',
      },
    ],
    'next_cursor': null,
  },
  'community_stats': (_) => {'alumni': 6340, 'activos': 5120, 'paises': 82, 'promociones': 51},
  'suggestions': (_) => [
    cardJson(
      id: 'u-7',
      nombre: 'Julia Sánchez Rubio',
      promocion: 34,
      cargo: null,
      empresa: 'Cepsa',
    ),
  ],
  'search_directory': (_) => {
    'items': [
      cardJson(),
      cardJson(
        id: 'u-8',
        nombre: 'Sara Molina Echevarría',
        fase: 'fase_2',
        promocion: 50,
        cargo: 'Becario/a en prácticas · Export',
        empresa: 'Cámara de Comercio de España',
      ),
    ],
    'total': 640,
    'next_cursor': 'x',
  },
});

Widget harness(Widget child, FakeApiClient api, {FakeAuthGateway? auth}) {
  final db = AppDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  return _harness(child, api, db, auth: auth);
}

Widget _harness(Widget child, FakeApiClient api, AppDatabase db, {FakeAuthGateway? auth}) =>
    ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        authGatewayProvider.overrideWithValue(auth ?? FakeAuthGateway(currentUserId: 'u-1')),
        realtimeGatewayProvider.overrideWithValue(FakeRealtime()),
        appDatabaseProvider.overrideWithValue(db),
        idGeneratorProvider.overrideWithValue(FakeIds()),
        appEnvProvider.overrideWithValue(
          const AppEnv(
            supabaseUrl: 'http://x',
            supabaseAnonKey: 'k',
            oidcProvider: 'custom:icex-alumni',
            authRedirect: 'x://y',
            environment: 'test',
            showDemoBanner: true,
          ),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: IcexTheme.light(),
        locale: const Locale('es'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: child,
      ),
    );

Future<void> pumpPhone(WidgetTester t, Widget w) async {
  await t.binding.setSurfaceSize(_phone);
  t.view.devicePixelRatio = 1;
  addTearDown(() => t.binding.setSurfaceSize(null));
  await t.pumpWidget(w);
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(milliseconds: 50));
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('Login', (t) async {
    await pumpPhone(t, harness(const LoginPage(), FakeApiClient(), auth: FakeAuthGateway()));
    expect(find.text('Entrar con mi cuenta ICEX Alumni'), findsOneWidget);
    await expectLater(find.byType(LoginPage), matchesGoldenFile('files/login.png'));
  });

  testWidgets('Acceso denegado', (t) async {
    await pumpPhone(t, harness(const AccessDeniedPage(), FakeApiClient(), auth: FakeAuthGateway()));
    expect(find.text('Acceso solo para socios'), findsOneWidget);
    await expectLater(
      find.byType(AccessDeniedPage),
      matchesGoldenFile('files/acceso_denegado.png'),
    );
  });

  testWidgets('Inicio (feed)', (t) async {
    final api = demoApi();
    await pumpPhone(t, harness(const Scaffold(body: HomePage()), api));
    expect(find.text('Ana Ortega Jiménez'), findsWidgets);
    expect(find.text('Comparte una novedad con la red ICEX Alumni…'), findsOneWidget);
    expect(find.textContaining('Reunión Anual'), findsOneWidget);
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('files/inicio.png'));
    // Recomendar dispara la llamada a la API
    api.responders['recommend'] = (_) => {'recomendado': true, 'recomendaciones_count': 77};
    await t.ensureVisible(find.text('Recomendar').first);
    await t.pump();
    await t.tap(find.text('Recomendar').first);
    await t.pump();
    expect(api.calls.any((c) => c.name == 'recommend'), isTrue);
  });

  testWidgets('Red (directorio)', (t) async {
    await pumpPhone(t, harness(const Scaffold(body: NetworkPage()), demoApi()));
    expect(find.text('Red de alumni'), findsOneWidget);
    expect(find.text('2 de 640 resultados'), findsOneWidget);
    await expectLater(find.byType(Scaffold).first, matchesGoldenFile('files/red.png'));
  });

  testWidgets('Tarjeta de publicación con badge y acciones', (t) async {
    final post = Post.fromJson(postJson(tipo: 'evento', createdAt: '2026-11-16T13:25:00Z'));
    await pumpPhone(
      t,
      harness(
        Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: PostCard(
              post: post,
              now: DateTime.utc(2026, 11, 16, 14),
              onRecommend: () {},
              onComment: () {},
              onShare: () {},
            ),
          ),
        ),
        FakeApiClient(),
      ),
    );
    expect(find.text('Evento'), findsOneWidget);
    expect(find.text('hace 35 min'), findsOneWidget);
    expect(find.text('76 recomendaciones'), findsOneWidget);
    await expectLater(find.byType(PostCard), matchesGoldenFile('files/post_card.png'));
  });

  testWidgets('Conversaciones y burbujas de chat', (t) async {
    final conv = Conversation.fromJson({
      'id': 'c1',
      'categoria': 'solicitud_informacion',
      'no_leidos': 1,
      'ultimo_mensaje_preview': '¿Te interesa más la instalación o conocer el entorno profesional?',
      'otro': cardJson(id: 'u-2', nombre: 'Javier Martín Jiménez'),
    });
    final mine = Message.fromJson(
      messageJson('m1', from: 'u-1', cuerpo: 'Hola Javier, me planteo pedir Singapur.'),
    );
    final theirs = Message.fromJson(messageJson('m2', cuerpo: '¡Encantado de ayudarte!'));
    await pumpPhone(
      t,
      harness(
        Scaffold(
          body: ListView(
            children: [
              ConversationTile(conversation: conv),
              const SizedBox(height: 16),
              MessageBubble(
                message: mine,
                mine: true,
                status: DeliveryStatus.leido,
                onRetry: () {},
              ),
              MessageBubble(
                message: theirs,
                mine: false,
                status: DeliveryStatus.enviado,
                onRetry: () {},
              ),
              MessageBubble(
                message: mine.withStatus(DeliveryStatus.error),
                mine: true,
                status: DeliveryStatus.error,
                onRetry: () {},
              ),
            ],
          ),
        ),
        FakeApiClient(),
      ),
    );
    expect(find.text('Solicitud de información'), findsOneWidget);
    expect(find.byIcon(Icons.done_all), findsOneWidget);
    await expectLater(find.byType(ListView), matchesGoldenFile('files/mensajes.png'));
  });

  testWidgets('Novedad y resultado del Orientador', (t) async {
    final news = Post.fromJson({
      ...postJson(tipo: 'novedad_oficial', createdAt: '2026-10-23T10:00:00Z'),
      'titulo': 'Reunión Anual ICEX Alumni 2026',
      'etiqueta': 'Evento',
      'fijado': true,
    });
    const q = OrientadorQuery(
      fase: Fase.fase1,
      pais: 'Alemania',
      sector: 'Energía',
      consulta: 'Entrevistas',
    );
    final r = OrientadorResult.fromJson(q, {
      'resumen': 'Estás dentro del programa y te interesa energía en Alemania.',
      'pasos': [
        'Prepara 3 historias con estructura situación–análisis–resultado.',
        'Empieza a contactar empresas de Fase II.',
      ],
      'alumni': [
        {
          'user_id': 'u',
          'slug': 's',
          'nombre': 'Irene Blanco Rubio',
          'motivo': 'Country Manager · Berlín',
          'fase': 'activo',
          'promocion': 31,
        },
      ],
      'aviso': 'Recomendaciones orientativas generadas con IA.',
      'restantes': 9,
    });
    await pumpPhone(
      t,
      harness(
        Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              NewsCard(post: news),
              const SizedBox(height: 16),
              OrientadorResultCard(result: r),
            ],
          ),
        ),
        FakeApiClient(),
      ),
    );
    expect(find.text('Fijado'), findsOneWidget);
    expect(find.text('Te quedan 9 consultas hoy'), findsOneWidget);
    await expectLater(find.byType(ListView), matchesGoldenFile('files/novedad_orientador.png'));
  });

  testWidgets('Semántica accesible: botones con etiqueta y objetivos ≥ 48 px', (t) async {
    final handle = t.ensureSemantics();
    await pumpPhone(t, harness(const LoginPage(), FakeApiClient(), auth: FakeAuthGateway()));
    await expectLater(t, meetsGuideline(androidTapTargetGuideline));
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    // El contraste se verifica por cálculo en test/core/core_test.dart (la guía por píxeles
    // da falsos positivos con la franja de color y el logotipo).
    handle.dispose();
  });
}
