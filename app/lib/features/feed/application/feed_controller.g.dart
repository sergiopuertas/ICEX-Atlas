// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Feed de Inicio. Se mantiene vivo mientras dura la sesión (no se recarga ni pierde la
/// paginación al cambiar de pestaña, como en LinkedIn o Instagram) y se descarta al cambiar
/// de usuario.

@ProviderFor(FeedController)
final feedControllerProvider = FeedControllerProvider._();

/// Feed de Inicio. Se mantiene vivo mientras dura la sesión (no se recarga ni pierde la
/// paginación al cambiar de pestaña, como en LinkedIn o Instagram) y se descarta al cambiar
/// de usuario.
final class FeedControllerProvider
    extends $AsyncNotifierProvider<FeedController, FeedState> {
  /// Feed de Inicio. Se mantiene vivo mientras dura la sesión (no se recarga ni pierde la
  /// paginación al cambiar de pestaña, como en LinkedIn o Instagram) y se descarta al cambiar
  /// de usuario.
  FeedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedControllerHash();

  @$internal
  @override
  FeedController create() => FeedController();
}

String _$feedControllerHash() => r'a3b3203f69ae328002782a584ad9184581233048';

/// Feed de Inicio. Se mantiene vivo mientras dura la sesión (no se recarga ni pierde la
/// paginación al cambiar de pestaña, como en LinkedIn o Instagram) y se descarta al cambiar
/// de usuario.

abstract class _$FeedController extends $AsyncNotifier<FeedState> {
  FutureOr<FeedState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<FeedState>, FeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FeedState>, FeedState>,
              AsyncValue<FeedState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(communityStats)
final communityStatsProvider = CommunityStatsProvider._();

final class CommunityStatsProvider
    extends
        $FunctionalProvider<
          AsyncValue<CommunityStats>,
          CommunityStats,
          FutureOr<CommunityStats>
        >
    with $FutureModifier<CommunityStats>, $FutureProvider<CommunityStats> {
  CommunityStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'communityStatsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$communityStatsHash();

  @$internal
  @override
  $FutureProviderElement<CommunityStats> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<CommunityStats> create(Ref ref) {
    return communityStats(ref);
  }
}

String _$communityStatsHash() => r'0a37e2243639994e3060e0c5d65009c12d1d7a28';

@ProviderFor(Suggestions)
final suggestionsProvider = SuggestionsProvider._();

final class SuggestionsProvider
    extends $AsyncNotifierProvider<Suggestions, List<ProfileCard>> {
  SuggestionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'suggestionsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$suggestionsHash();

  @$internal
  @override
  Suggestions create() => Suggestions();
}

String _$suggestionsHash() => r'586b4cac4dbab02d5a760015d2df468bb7ab8f09';

abstract class _$Suggestions extends $AsyncNotifier<List<ProfileCard>> {
  FutureOr<List<ProfileCard>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<ProfileCard>>, List<ProfileCard>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ProfileCard>>, List<ProfileCard>>,
              AsyncValue<List<ProfileCard>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(NewsController)
final newsControllerProvider = NewsControllerProvider._();

final class NewsControllerProvider
    extends $AsyncNotifierProvider<NewsController, FeedState> {
  NewsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'newsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$newsControllerHash();

  @$internal
  @override
  NewsController create() => NewsController();
}

String _$newsControllerHash() => r'3c08d90b7e846be1697d33820a1a411a7a66a724';

abstract class _$NewsController extends $AsyncNotifier<FeedState> {
  FutureOr<FeedState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<FeedState>, FeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FeedState>, FeedState>,
              AsyncValue<FeedState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
