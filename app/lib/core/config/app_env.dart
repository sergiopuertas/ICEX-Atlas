// Los valores de `fromEnvironment` cambian en compilación; el analizador los evalúa sin
// defines y los marca como redundantes, por eso se desactiva la regla en este fichero.
// ignore_for_file: avoid_redundant_argument_values

/// Configuración inyectada en compilación con `--dart-define` (o `--dart-define-from-file`).
///
/// Ver `.env.example` en la raíz del repositorio. Nunca se incluye aquí la clave
/// `service_role`: la app solo conoce la clave pública (anon/publishable).
class AppEnv {
  const AppEnv({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.oidcProvider,
    required this.authRedirect,
    required this.environment,
    this.sentryDsn = '',
    this.mapTileUrl = defaultTileUrl,
    this.mapTileAttribution = defaultTileAttribution,
    this.associationWebUrl = 'https://icex-alumni.es',
    this.showDemoBanner = false,
  });

  factory AppEnv.fromEnvironment() => const AppEnv(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL', defaultValue: 'http://127.0.0.1:54321'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    oidcProvider: String.fromEnvironment('OIDC_PROVIDER', defaultValue: 'custom:icex-alumni'),
    authRedirect: String.fromEnvironment(
      'AUTH_REDIRECT',
      defaultValue: 'es.icexalumni.atlas://login-callback',
    ),
    environment: String.fromEnvironment('APP_ENV', defaultValue: 'local'),
    sentryDsn: String.fromEnvironment('SENTRY_DSN'),
    mapTileUrl: String.fromEnvironment('MAP_TILE_URL', defaultValue: defaultTileUrl),
    mapTileAttribution: String.fromEnvironment(
      'MAP_TILE_ATTRIBUTION',
      defaultValue: defaultTileAttribution,
    ),
    associationWebUrl: String.fromEnvironment(
      'ASSOCIATION_WEB_URL',
      defaultValue: 'https://icex-alumni.es',
    ),
    showDemoBanner: bool.fromEnvironment('SHOW_DEMO_BANNER', defaultValue: true),
  );

  static const defaultTileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const defaultTileAttribution = '© OpenStreetMap contributors';

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String oidcProvider;
  final String authRedirect;
  final String environment;
  final String sentryDsn;
  final String mapTileUrl;
  final String mapTileAttribution;
  final String associationWebUrl;
  final bool showDemoBanner;

  bool get isProduction => environment == 'production';
  bool get hasSentry => sentryDsn.isNotEmpty;
}
