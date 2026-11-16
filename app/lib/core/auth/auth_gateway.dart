import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

sealed class AuthEvent {
  const AuthEvent();
}

final class AuthSignedIn extends AuthEvent {
  const AuthSignedIn(this.userId);

  final String userId;
}

final class AuthSignedOut extends AuthEvent {
  const AuthSignedOut();
}

/// Error devuelto por el flujo OAuth (p. ej. el hook rechaza a un no socio).
final class AuthFailed extends AuthEvent {
  const AuthFailed(this.message);

  final String message;

  /// El hook `before_user_created` / `custom_access_token` rechazó al usuario.
  bool get isNotMember =>
      message.contains('icex_member_not_verified') || message.contains('icex_member_not_active');
}

/// Abstracción de Supabase Auth (testeable sin red).
abstract interface class AuthGateway {
  String? get currentUserId;

  Stream<AuthEvent> get events;

  /// «Entrar con mi cuenta ICEX Alumni» → OIDC (WordPress) con PKCE.
  Future<void> signIn();

  Future<void> signOut();
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._auth, {required this.provider, required this.redirectTo});

  final GoTrueClient _auth;
  final String provider;
  final String redirectTo;

  @override
  String? get currentUserId => _auth.currentSession?.user.id;

  @override
  Stream<AuthEvent> get events => _auth.onAuthStateChange.transform(
    StreamTransformer.fromHandlers(
      handleData: (state, sink) {
        final e = state.event;
        if (e == AuthChangeEvent.signedOut) {
          sink.add(const AuthSignedOut());
        } else if (e == AuthChangeEvent.initialSession ||
            e == AuthChangeEvent.signedIn ||
            e == AuthChangeEvent.tokenRefreshed ||
            e == AuthChangeEvent.userUpdated) {
          final uid = state.session?.user.id;
          sink.add(uid == null ? const AuthSignedOut() : AuthSignedIn(uid));
        }
      },
      handleError: (error, _, sink) =>
          sink.add(AuthFailed(error is AuthException ? error.message : error.toString())),
    ),
  );

  @override
  Future<void> signIn() async {
    await _auth.signInWithOAuth(
      OAuthProvider(provider),
      redirectTo: redirectTo,
      scopes: 'openid profile email',
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
