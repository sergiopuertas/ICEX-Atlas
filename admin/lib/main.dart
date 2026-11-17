import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:icex_atlas_admin/admin_api.dart';
import 'package:icex_atlas_admin/pages.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _url = String.fromEnvironment('SUPABASE_URL', defaultValue: 'http://127.0.0.1:54321');
const _key = String.fromEnvironment('SUPABASE_ANON_KEY');
const _provider = String.fromEnvironment('OIDC_PROVIDER', defaultValue: 'custom:icex-alumni');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: _url,
    publishableKey: _key,
    postgrestOptions: const PostgrestClientOptions(schema: 'api'),
  );
  runApp(const AdminApp());
}

const icexRed = Color(0xFFC50516);

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'ICEX Atlas · Administración',
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: icexRed, primary: icexRed),
      scaffoldBackgroundColor: const Color(0xFFF9F6F4),
    ),
    home: const AuthGate(),
  );
}

/// Solo administración/moderación: el rol se comprueba con api.me() (y de nuevo en cada RPC).
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;
    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, _) {
        if (auth.currentSession == null) return const _Login();
        return FutureBuilder<Map<String, dynamic>>(
          future: AdminApi(Supabase.instance.client).me(),
          builder: (context, snap) {
            if (snap.hasError) return const _Denied();
            if (!snap.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            final role = snap.data!['role'] as String?;
            if (role != 'admin' && role != 'moderador') return const _Denied();
            return AdminHome(api: AdminApi(Supabase.instance.client), isAdmin: role == 'admin');
          },
        );
      },
    );
  }
}

class _Login extends StatelessWidget {
  const _Login();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('ICEX Atlas · Administración', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Supabase.instance.client.auth.signInWithOAuth(
                  const OAuthProvider(_provider),
                  redirectTo: Uri.base.origin,
                  scopes: 'openid profile email',
                ),
                icon: const Icon(Icons.login),
                label: const Text('Entrar con mi cuenta ICEX Alumni'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Denied extends StatelessWidget {
  const _Denied();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 48, color: icexRed),
          const SizedBox(height: 12),
          const Text('Acceso reservado a administración y moderación.'),
          TextButton(
            onPressed: () => Supabase.instance.client.auth.signOut(),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    ),
  );
}
