// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'feed_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FeedController)
final feedControllerProvider = FeedControllerProvider._();

final class FeedControllerProvider extends $AsyncNotifierProvider<FeedController, FeedState> {
  FeedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedControllerHash();

  @$internal
  @override
  FeedController create() => FeedController();
}

String _$feedControllerHash() => r'b6238417293475c550ebab0aeba9dafc7087879e';

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
        $FunctionalProvider<AsyncValue<CommunityStats>, CommunityStats, FutureOr<CommunityStats>>
    with $FutureModifier<CommunityStats>, $FutureProvider<CommunityStats> {
  CommunityStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'communityStatsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$communityStatsHash();

  @$internal
  @override
  $FutureProviderElement<CommunityStats> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<CommunityStats> create(Ref ref) {
    return communityStats(ref);
  }
}

String _$communityStatsHash() => r'c3364785ceacdf2de9b0d01518d7f0de5433fffc';

@ProviderFor(Suggestions)
final suggestionsProvider = SuggestionsProvider._();

final class SuggestionsProvider extends $AsyncNotifierProvider<Suggestions, List<ProfileCard>> {
  SuggestionsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'suggestionsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$suggestionsHash();

  @$internal
  @override
  Suggestions create() => Suggestions();
}

String _$suggestionsHash() => r'a777f3f2ae637b1b1ff810e2a074de3bdd18254f';

abstract class _$Suggestions extends $AsyncNotifier<List<ProfileCard>> {
  FutureOr<List<ProfileCard>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<ProfileCard>>, List<ProfileCard>>;
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

final class NewsControllerProvider extends $AsyncNotifierProvider<NewsController, FeedState> {
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

String _$newsControllerHash() => r'b016517a84a0faa28750c7713ad0fc178598aa2c';

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
