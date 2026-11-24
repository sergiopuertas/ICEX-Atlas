// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unread_counts.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// No leídos (mensajes y notificaciones) para los badges. Se refresca con los eventos
/// del canal privado `user:<id>` de Realtime.

@ProviderFor(Unread)
final unreadProvider = UnreadProvider._();

/// No leídos (mensajes y notificaciones) para los badges. Se refresca con los eventos
/// del canal privado `user:<id>` de Realtime.
final class UnreadProvider
    extends $AsyncNotifierProvider<Unread, UnreadCounts> {
  /// No leídos (mensajes y notificaciones) para los badges. Se refresca con los eventos
  /// del canal privado `user:<id>` de Realtime.
  UnreadProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadHash();

  @$internal
  @override
  Unread create() => Unread();
}

String _$unreadHash() => r'3522217cda273df05b85c7e16831e20b92d95efd';

/// No leídos (mensajes y notificaciones) para los badges. Se refresca con los eventos
/// del canal privado `user:<id>` de Realtime.

abstract class _$Unread extends $AsyncNotifier<UnreadCounts> {
  FutureOr<UnreadCounts> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UnreadCounts>, UnreadCounts>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UnreadCounts>, UnreadCounts>,
              AsyncValue<UnreadCounts>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
