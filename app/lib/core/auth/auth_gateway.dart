import 'dart:async';
import 'dart:convert';

import 'package:icex_atlas/core/utils/ids.dart';
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

/// Se abrió el enlace de «He olvidado mi contraseña»: hay sesión, pero hay que pedir una
/// contraseña nueva antes de entrar.
final class AuthPasswordRecovery extends AuthEvent {
  const AuthPasswordRecovery(this.userId);

  final String userId;
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
  ///
  /// [forceLogin] pide al proveedor que vuelva a mostrar el formulario de acceso
  /// (`prompt=login`, estándar OIDC) aunque recuerde una sesión anterior. Sin esto, tras un
  /// «acceso solo para socios» el proveedor volvía a entrar automáticamente con la misma
  /// cuenta no socia y era imposible probar con otra.
  Future<void> signIn({bool forceLogin = false});

  /// Email y contraseña: beta abierta (`AUTH_MODE=password`) y acceso de desarrollo.
  Future<void> signInWithPassword({required String email, required String password});

  /// Crea una cuenta con email y contraseña (beta abierta). Devuelve `true` si hace falta
  /// confirmar el correo antes de entrar (no hay sesión todavía).
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    int? promocion,
  });

  /// Reenvía el correo de confirmación del alta.
  Future<void> resendConfirmation(String email);

  /// Envía el correo para elegir una contraseña nueva.
  Future<void> sendPasswordReset(String email);

  /// Cambia la contraseña de la sesión actual (tras el enlace de recuperación).
  Future<void> updatePassword(String newPassword);

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
        } else if (e == AuthChangeEvent.passwordRecovery && state.session != null) {
          sink.add(AuthPasswordRecovery(state.session!.user.id));
        } else if (e == AuthChangeEvent.initialSession ||
            e == AuthChangeEvent.signedIn ||
            e == AuthChangeEvent.tokenRefreshed ||
            e == AuthChangeEvent.userUpdated) {
          final uid = state.session?.user.id;
          if (e == AuthChangeEvent.signedIn || e == AuthChangeEvent.tokenRefreshed) {
            _observeServerTime(state.session?.accessToken);
          }
          sink.add(uid == null ? const AuthSignedOut() : AuthSignedIn(uid));
        }
      },
      handleError: (error, _, sink) =>
          sink.add(AuthFailed(error is AuthException ? error.message : error.toString())),
    ),
  );

  /// Un token recién emitido trae en `iat` la hora del servidor: corrige el reloj de los ids.
  static void _observeServerTime(String? jwt) {
    final parts = jwt?.split('.');
    if (parts == null || parts.length != 3) return;
    try {
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      final iat = (payload as Map<String, dynamic>)['iat'];
      if (iat is int) ServerClock.instance.observe(DateTime.fromMillisecondsSinceEpoch(iat * 1000));
    } on Object {
      // Token ilegible: no corregimos nada.
    }
  }

  @override
  Future<void> signInWithPassword({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    int? promocion,
  }) async {
    final r = await _auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: redirectTo,
      data: {'name': name, 'promocion': ?promocion?.toString()},
    );
    return r.session == null;
  }

  @override
  Future<void> resendConfirmation(String email) =>
      _auth.resend(type: OtpType.signup, email: email, emailRedirectTo: redirectTo);

  @override
  Future<void> sendPasswordReset(String email) =>
      _auth.resetPasswordForEmail(email, redirectTo: redirectTo);

  @override
  Future<void> updatePassword(String newPassword) async {
    await _auth.updateUser(UserAttributes(password: newPassword));
  }

  @override
  Future<void> signIn({bool forceLogin = false}) async {
    await _auth.signInWithOAuth(
      OAuthProvider(provider),
      redirectTo: redirectTo,
      scopes: 'openid profile email',
      // Supabase Auth reenvía estos parámetros al proveedor OIDC.
      queryParams: forceLogin ? const {'prompt': 'login', 'max_age': '0'} : null,
      authScreenLaunchMode: LaunchMode.externalApplication,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();
}
