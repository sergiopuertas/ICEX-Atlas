import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    state = const SigningIn();
    try {
      await ref.read(authGatewayProvider).signIn(forceLogin: switchAccount || _forceLogin);
    } on Object catch (e) {
      if (ref.mounted) state = SignedOut(error: e.toString());
    }
  }

  /// Acceso rápido de desarrollo (sin navegador). Los errores se tratan igual que los del
  /// flujo OIDC: una cuenta sin membresía termina en «Acceso solo para socios».
  Future<void> signInWithPassword({required String email, required String password}) async {
    state = const SigningIn();
    try {
      await ref.read(authGatewayProvider).signInWithPassword(email: email, password: password);
    } on Object catch (e) {
      if (!ref.mounted) return;
      final msg = e.toString();
      if (msg.contains('icex_member')) {
        _denied();
      } else {
        state = SignedOut(error: msg);
      }
    }
  }

  /// La app vuelve al primer plano sin respuesta del proveedor: el usuario cerró el
  /// navegador o volvió atrás sin completar el acceso. Antes la pantalla se quedaba en
  /// «Conectando…» con el botón desactivado para siempre.
  void signInAbandoned() {
    if (state is SigningIn) state = const SignedOut();
  }

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
      case AuthSignedIn(:final userId):
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
    bool stale() => !ref.mounted || _loadedFor != userId;
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
