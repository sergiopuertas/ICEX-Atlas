import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:icex_atlas/core/auth/auth_errors.dart';
import 'package:icex_atlas/core/auth/auth_gateway.dart';
import 'package:icex_atlas/core/errors/failure.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'session_controller.g.dart';

sealed class SessionState {
  const SessionState();
}

final class SessionUnknown extends SessionState {
  const SessionUnknown();
}

final class SignedOut extends SessionState {
  const SignedOut({this.error});

  final String? error;
}

final class SigningIn extends SessionState {
  const SigningIn();
}

final class SignedIn extends SessionState {
  const SignedIn(this.me);

  final Me me;
}

/// Alta hecha: falta abrir el enlace del correo de confirmación.
final class AwaitingConfirmation extends SessionState {
  const AwaitingConfirmation(this.email, {this.resent = false, this.error});

  final String email;
  final bool resent;
  final String? error;
}

/// Se abrió el enlace de recuperación: hay que elegir una contraseña nueva.
final class PasswordRecovery extends SessionState {
  const PasswordRecovery(this.userId, {this.busy = false, this.error});

  final String userId;
  final bool busy;
  final String? error;
}

/// Quien no es socio verificado no ve ninguna pantalla con contenido.
final class AccessDenied extends SessionState {
  const AccessDenied();
}

@Riverpod(keepAlive: true)
class SessionController extends _$SessionController {
  StreamSubscription<AuthEvent>? _sub;
  String? _loadedFor;

  /// El próximo acceso debe pedir usuario de nuevo: tras «acceso solo para socios» o tras
  /// cerrar sesión (para poder entrar con otra cuenta).
  bool _forceLogin = false;

  /// Solo el acceso por navegador (OIDC) puede quedar «abandonado» al volver a la app; un
  /// formulario de email y contraseña en curso no.
  bool _oidcStarted = false;

  @override
  SessionState build() {
    final gateway = ref.watch(authGatewayProvider);
    _sub = gateway.events.listen(_onEvent);
    ref.onDispose(() => _sub?.cancel());
    final uid = gateway.currentUserId;
    if (uid != null) {
      unawaited(_loadMe(uid));
      return const SessionUnknown();
    }
    return const SignedOut();
  }

  /// [switchAccount]: entrar con otra cuenta (fuerza el formulario del proveedor).
  Future<void> signIn({bool switchAccount = false}) async {
    _oidcStarted = true;
    state = const SigningIn();
    try {
      await ref.read(authGatewayProvider).signIn(forceLogin: switchAccount || _forceLogin);
    } on Object catch (e) {
      if (ref.mounted) state = SignedOut(error: e.toString());
    }
  }

  /// Email y contraseña (beta abierta y acceso de desarrollo). Una cuenta sin membresía
  /// termina en «Acceso solo para socios», igual que en el flujo OIDC.
  Future<void> signInWithPassword({required String email, required String password}) async {
    _oidcStarted = false;
    state = const SigningIn();
    try {
      await ref
          .read(authGatewayProvider)
          .signInWithPassword(email: email.trim(), password: password);
    } on Object catch (e) {
      if (!ref.mounted) return;
      final code = authErrorCode(e);
      if (code == AuthErrorCode.notMember) {
        _denied();
      } else if (code == AuthErrorCode.emailNotConfirmed) {
        state = AwaitingConfirmation(email.trim());
      } else {
        state = SignedOut(error: code);
      }
    }
  }

  /// Alta en la beta abierta. Si hace falta confirmar el correo, se queda esperando; si no,
  /// llega la sesión por el flujo normal (evento de Auth).
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    int? promocion,
  }) async {
    _oidcStarted = false;
    state = const SigningIn();
    try {
      final needsConfirmation = await ref
          .read(authGatewayProvider)
          .signUp(email: email.trim(), password: password, name: name.trim(), promocion: promocion);
      if (!ref.mounted) return;
      if (needsConfirmation) state = AwaitingConfirmation(email.trim());
    } on Object catch (e) {
      if (ref.mounted) state = SignedOut(error: authErrorCode(e));
    }
  }

  Future<void> resendConfirmation() async {
    final s = state;
    if (s is! AwaitingConfirmation) return;
    try {
      await ref.read(authGatewayProvider).resendConfirmation(s.email);
      if (ref.mounted) state = AwaitingConfirmation(s.email, resent: true);
    } on Object catch (e) {
      if (ref.mounted) state = AwaitingConfirmation(s.email, error: authErrorCode(e));
    }
  }

  /// Envía el correo de «nueva contraseña». Devuelve el código de error, o `null` si fue bien.
  /// Por privacidad la app no distingue si el correo existe o no.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await ref.read(authGatewayProvider).sendPasswordReset(email.trim());
      return null;
    } on Object catch (e) {
      return authErrorCode(e);
    }
  }

  /// Guarda la contraseña nueva tras el enlace de recuperación y entra en la app.
  Future<void> updatePassword(String newPassword) async {
    final s = state;
    if (s is! PasswordRecovery) return;
    state = PasswordRecovery(s.userId, busy: true);
    try {
      await ref.read(authGatewayProvider).updatePassword(newPassword);
      if (!ref.mounted) return;
      _loadedFor = null;
      state = const SessionUnknown();
      await _loadMe(s.userId);
    } on Object catch (e) {
      if (ref.mounted) state = PasswordRecovery(s.userId, error: authErrorCode(e));
    }
  }

  /// La app vuelve al primer plano sin respuesta del proveedor: el usuario cerró el
  /// navegador o volvió atrás sin completar el acceso. Antes la pantalla se quedaba en
  /// «Conectando…» con el botón desactivado para siempre.
  void signInAbandoned() {
    if (state is SigningIn && _oidcStarted) state = const SignedOut();
  }

  /// Volver a la portada desde «Revisa tu correo».
  void backToStart() => state = const SignedOut();

  void _denied() {
    _forceLogin = true;
    state = const AccessDenied();
  }

  Future<void> signOut() async {
    _loadedFor = null;
    _forceLogin = true;
    try {
      await ref.read(appDatabaseProvider).wipe();
    } on Object {
      // La caché local no debe impedir cerrar sesión.
    }
    try {
      await ref.read(authGatewayProvider).signOut();
    } finally {
      state = const SignedOut();
    }
  }

  /// Vuelve a cargar el perfil propio (tras editarlo).
  ///
  /// A diferencia de la carga inicial, un fallo aquí (p. ej. red) NO cierra la sesión:
  /// se conserva el perfil anterior. Antes, editar el perfil con mala cobertura echaba
  /// al usuario a la pantalla de login.
  Future<void> refreshMe() async {
    final s = state;
    if (s is! SignedIn) return;
    try {
      final me = await ref.read(profilesRepositoryProvider).me();
      if (ref.mounted && state is SignedIn && _loadedFor == me.userId) state = SignedIn(me);
    } on ForbiddenFailure {
      if (!ref.mounted) return;
      _denied();
      await ref.read(authGatewayProvider).signOut();
    } on AppFailure {
      // Conservar el estado actual.
    }
  }

  void _onEvent(AuthEvent e) {
    switch (e) {
      case AuthPasswordRecovery(:final userId):
        _loadedFor = null;
        state = PasswordRecovery(userId);
      case AuthSignedIn(:final userId):
        // Durante la recuperación de contraseña no se entra hasta elegir una nueva.
        if (state is PasswordRecovery) return;
        if (_loadedFor != userId) unawaited(_loadMe(userId));
      case AuthSignedOut():
        _loadedFor = null;
        if (state is! AccessDenied) state = const SignedOut();
      case AuthFailed(:final isNotMember, :final message):
        if (isNotMember) {
          _denied();
        } else {
          state = SignedOut(error: message);
        }
    }
  }

  Future<void> _loadMe(String userId) async {
    _loadedFor = userId;
    // Si mientras tanto se cerró sesión o entró otro usuario, la respuesta es obsoleta.
    bool stale() => !ref.mounted || _loadedFor != userId || state is PasswordRecovery;
    try {
      final me = await ref.read(profilesRepositoryProvider).me();
      if (stale()) return;
      _forceLogin = false;
      state = SignedIn(me);
    } on ForbiddenFailure {
      if (stale()) return;
      // JWT válido pero sin membresía activa (baja): fuera.
      _denied();
      await ref.read(authGatewayProvider).signOut();
    } on NetworkFailure {
      if (stale()) return;
      _loadedFor = null;
      state = const SignedOut(error: 'network');
    } on AppFailure catch (e) {
      if (stale()) return;
      _loadedFor = null;
      state = SignedOut(error: e.message);
    }
  }

  /// Desde la pantalla de acceso denegado: vuelve al inicio y el próximo acceso pedirá
  /// usuario de nuevo.
  void reset() {
    _forceLogin = true;
    state = const SignedOut();
  }
}

/// Id del usuario con sesión, o `null`.
///
/// Los servicios ligados a la sesión (push, presencia, no leídos, Realtime) deben depender de
/// esto y no de [sessionControllerProvider]: ese estado cambia cada vez que se recarga el
/// perfil (editar, cambiar foto, privacidad…), y antes eso reiniciaba el servicio de push
/// (que al pararse da de baja el token del dispositivo), la presencia y las suscripciones
/// de Realtime.
@Riverpod(keepAlive: true)
String? sessionUserId(Ref ref) =>
    ref.watch(sessionControllerProvider.select((s) => s is SignedIn ? s.me.userId : null));
