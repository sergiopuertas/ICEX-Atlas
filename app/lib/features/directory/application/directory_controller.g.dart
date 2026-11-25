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

String _$directoryControllerHash() => r'7f25eaf44fca4c5f455b6560af3de99f3ee1111a';

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
