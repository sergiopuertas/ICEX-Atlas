// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SessionController)
final sessionControllerProvider = SessionControllerProvider._();

final class SessionControllerProvider
    extends $NotifierProvider<SessionController, SessionState> {
  SessionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionControllerHash();

  @$internal
  @override
  SessionController create() => SessionController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionState>(value),
    );
  }
}

String _$sessionControllerHash() => r'd373901837c822906ae9bdbb525b98a60359f6ca';

abstract class _$SessionController extends $Notifier<SessionState> {
  SessionState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SessionState, SessionState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SessionState, SessionState>,
              SessionState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Id del usuario con sesión, o `null`.
///
/// Los servicios ligados a la sesión (push, presencia, no leídos, Realtime) deben depender de
/// esto y no de [sessionControllerProvider]: ese estado cambia cada vez que se recarga el
/// perfil (editar, cambiar foto, privacidad…), y antes eso reiniciaba el servicio de push
/// (que al pararse da de baja el token del dispositivo), la presencia y las suscripciones
/// de Realtime.

@ProviderFor(sessionUserId)
final sessionUserIdProvider = SessionUserIdProvider._();

/// Id del usuario con sesión, o `null`.
///
/// Los servicios ligados a la sesión (push, presencia, no leídos, Realtime) deben depender de
/// esto y no de [sessionControllerProvider]: ese estado cambia cada vez que se recarga el
/// perfil (editar, cambiar foto, privacidad…), y antes eso reiniciaba el servicio de push
/// (que al pararse da de baja el token del dispositivo), la presencia y las suscripciones
/// de Realtime.

final class SessionUserIdProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Id del usuario con sesión, o `null`.
  ///
  /// Los servicios ligados a la sesión (push, presencia, no leídos, Realtime) deben depender de
  /// esto y no de [sessionControllerProvider]: ese estado cambia cada vez que se recarga el
  /// perfil (editar, cambiar foto, privacidad…), y antes eso reiniciaba el servicio de push
  /// (que al pararse da de baja el token del dispositivo), la presencia y las suscripciones
  /// de Realtime.
  SessionUserIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionUserIdProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionUserIdHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return sessionUserId(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$sessionUserIdHash() => r'049c812fb5cc8e3cae02db8b038d38064a055cce';
