// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'directory_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DirectoryController)
final directoryControllerProvider = DirectoryControllerProvider._();

final class DirectoryControllerProvider
    extends $NotifierProvider<DirectoryController, DirectoryState> {
  DirectoryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directoryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directoryControllerHash();

  @$internal
  @override
  DirectoryController create() => DirectoryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DirectoryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DirectoryState>(value),
    );
  }
}

String _$directoryControllerHash() => r'9b4cf2937c984ac3dc9a3a955b382af632017661';

abstract class _$DirectoryController extends $Notifier<DirectoryState> {
  DirectoryState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<DirectoryState, DirectoryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<DirectoryState, DirectoryState>,
              DirectoryState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
