// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProfileController)
final profileControllerProvider = ProfileControllerFamily._();

final class ProfileControllerProvider
    extends $AsyncNotifierProvider<ProfileController, ProfileDetail> {
  ProfileControllerProvider._({
    required ProfileControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileControllerHash();

  @override
  String toString() {
    return r'profileControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProfileController create() => ProfileController();

  @override
  bool operator ==(Object other) {
    return other is ProfileControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileControllerHash() => r'df3fcb237c25ca972fe8d5f3473cc098beb60460';

final class ProfileControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ProfileController,
          AsyncValue<ProfileDetail>,
          ProfileDetail,
          FutureOr<ProfileDetail>,
          String
        > {
  ProfileControllerFamily._()
    : super(
        retry: null,
        name: r'profileControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProfileControllerProvider call(String slug) =>
      ProfileControllerProvider._(argument: slug, from: this);

  @override
  String toString() => r'profileControllerProvider';
}

abstract class _$ProfileController extends $AsyncNotifier<ProfileDetail> {
  late final _$args = ref.$arg as String;
  String get slug => _$args;

  FutureOr<ProfileDetail> build(String slug);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ProfileDetail>, ProfileDetail>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProfileDetail>, ProfileDetail>,
              AsyncValue<ProfileDetail>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}

@ProviderFor(userPosts)
final userPostsProvider = UserPostsFamily._();

final class UserPostsProvider
    extends $FunctionalProvider<AsyncValue<List<Post>>, List<Post>, FutureOr<List<Post>>>
    with $FutureModifier<List<Post>>, $FutureProvider<List<Post>> {
  UserPostsProvider._({required UserPostsFamily super.from, required String super.argument})
    : super(
        retry: null,
        name: r'userPostsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userPostsHash();

  @override
  String toString() {
    return r'userPostsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Post>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<Post>> create(Ref ref) {
    final argument = this.argument as String;
    return userPosts(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is UserPostsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$userPostsHash() => r'2f3f5285a1db0bb6341c2c1d93c9463a04e9b682';

final class UserPostsFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Post>>, String> {
  UserPostsFamily._()
    : super(
        retry: null,
        name: r'userPostsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  UserPostsProvider call(String userId) => UserPostsProvider._(argument: userId, from: this);

  @override
  String toString() => r'userPostsProvider';
}
