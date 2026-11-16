import 'dart:async';

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

  Future<void> signIn() async {
    state = const SigningIn();
    try {
      await ref.read(authGatewayProvider).signIn();
    } on Object catch (e) {
      state = SignedOut(error: e.toString());
    }
  }

  Future<void> signOut() async {
    _loadedFor = null;
    await ref.read(appDatabaseProvider).wipe();
    await ref.read(authGatewayProvider).signOut();
    state = const SignedOut();
  }

  /// Vuelve a cargar el perfil propio (tras editarlo).
  Future<void> refreshMe() async {
    final s = state;
    if (s is SignedIn) {
      _loadedFor = null;
      await _loadMe(s.me.userId);
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
        state = isNotMember ? const AccessDenied() : SignedOut(error: message);
    }
  }

  Future<void> _loadMe(String userId) async {
    _loadedFor = userId;
    try {
      final me = await ref.read(profilesRepositoryProvider).me();
      state = SignedIn(me);
    } on ForbiddenFailure {
      // JWT válido pero sin membresía activa (baja): fuera.
      state = const AccessDenied();
      await ref.read(authGatewayProvider).signOut();
    } on NetworkFailure {
      _loadedFor = null;
      state = const SignedOut(error: 'network');
    } on AppFailure catch (e) {
      _loadedFor = null;
      state = SignedOut(error: e.message);
    }
  }

  /// Desde la pantalla de acceso denegado.
  void reset() => state = const SignedOut();
}
