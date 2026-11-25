// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_interactions.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PostOverrides)
final postOverridesProvider = PostOverridesProvider._();

final class PostOverridesProvider extends $NotifierProvider<PostOverrides, PostOverridesState> {
  PostOverridesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'postOverridesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$postOverridesHash();

  @$internal
  @override
  PostOverrides create() => PostOverrides();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PostOverridesState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PostOverridesState>(value),
    );
  }
}

String _$postOverridesHash() => r'c2ba482823de457fb97f5415ad7ddab1e8998ada';

abstract class _$PostOverrides extends $Notifier<PostOverridesState> {
  PostOverridesState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PostOverridesState, PostOverridesState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PostOverridesState, PostOverridesState>,
              PostOverridesState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
