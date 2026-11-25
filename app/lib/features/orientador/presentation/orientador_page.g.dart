// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'orientador_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OrientadorController)
final orientadorControllerProvider = OrientadorControllerProvider._();

final class OrientadorControllerProvider
    extends $NotifierProvider<OrientadorController, OrientadorState> {
  OrientadorControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'orientadorControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$orientadorControllerHash();

  @$internal
  @override
  OrientadorController create() => OrientadorController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OrientadorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OrientadorState>(value),
    );
  }
}

String _$orientadorControllerHash() => r'34c0cec69faa57dadfa4c19d9d72d210de8a2604';

abstract class _$OrientadorController extends $Notifier<OrientadorState> {
  OrientadorState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<OrientadorState, OrientadorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OrientadorState, OrientadorState>,
              OrientadorState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
