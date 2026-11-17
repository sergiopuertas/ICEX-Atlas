// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_detail_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(postDetail)
final postDetailProvider = PostDetailFamily._();

final class PostDetailProvider
    extends $FunctionalProvider<AsyncValue<Post>, Post, FutureOr<Post>>
    with $FutureModifier<Post>, $FutureProvider<Post> {
  PostDetailProvider._({
    required PostDetailFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'postDetailProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$postDetailHash();

  @override
  String toString() {
    return r'postDetailProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Post> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Post> create(Ref ref) {
    final argument = this.argument as String;
    return postDetail(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PostDetailProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$postDetailHash() => r'1f97076cb5b4afa41bb05b2a1b6012d61fd53abf';

final class PostDetailFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Post>, String> {
  PostDetailFamily._()
    : super(
        retry: null,
        name: r'postDetailProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PostDetailProvider call(String id) =>
      PostDetailProvider._(argument: id, from: this);

  @override
  String toString() => r'postDetailProvider';
}

@ProviderFor(CommentsController)
final commentsControllerProvider = CommentsControllerFamily._();

final class CommentsControllerProvider
    extends $AsyncNotifierProvider<CommentsController, List<Comment>> {
  CommentsControllerProvider._({
    required CommentsControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'commentsControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$commentsControllerHash();

  @override
  String toString() {
    return r'commentsControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  CommentsController create() => CommentsController();

  @override
  bool operator ==(Object other) {
    return other is CommentsControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$commentsControllerHash() =>
    r'6d9278f3868a734661b4fb8ecfeb6e43596ddb0b';

final class CommentsControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          CommentsController,
          AsyncValue<List<Comment>>,
          List<Comment>,
          FutureOr<List<Comment>>,
          String
        > {
  CommentsControllerFamily._()
    : super(
        retry: null,
        name: r'commentsControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CommentsControllerProvider call(String postId) =>
      CommentsControllerProvider._(argument: postId, from: this);

  @override
  String toString() => r'commentsControllerProvider';
}

abstract class _$CommentsController extends $AsyncNotifier<List<Comment>> {
  late final _$args = ref.$arg as String;
  String get postId => _$args;

  FutureOr<List<Comment>> build(String postId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<Comment>>, List<Comment>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<Comment>>, List<Comment>>,
              AsyncValue<List<Comment>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
