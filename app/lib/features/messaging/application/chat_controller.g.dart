// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ChatController)
final chatControllerProvider = ChatControllerFamily._();

final class ChatControllerProvider
    extends $AsyncNotifierProvider<ChatController, ChatState> {
  ChatControllerProvider._({
    required ChatControllerFamily super.from,
    required ({String? conversationId, String? toUserId}) super.argument,
  }) : super(
         retry: null,
         name: r'chatControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatControllerHash();

  @override
  String toString() {
    return r'chatControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ChatController create() => ChatController();

  @override
  bool operator ==(Object other) {
    return other is ChatControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatControllerHash() => r'0b476816ad948bedd9610f4fb37cad6e787788b5';

final class ChatControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ChatController,
          AsyncValue<ChatState>,
          ChatState,
          FutureOr<ChatState>,
          ({String? conversationId, String? toUserId})
        > {
  ChatControllerFamily._()
    : super(
        retry: null,
        name: r'chatControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ChatControllerProvider call({String? conversationId, String? toUserId}) =>
      ChatControllerProvider._(
        argument: (conversationId: conversationId, toUserId: toUserId),
        from: this,
      );

  @override
  String toString() => r'chatControllerProvider';
}

abstract class _$ChatController extends $AsyncNotifier<ChatState> {
  late final _$args = ref.$arg as ({String? conversationId, String? toUserId});
  String? get conversationId => _$args.conversationId;
  String? get toUserId => _$args.toUserId;

  FutureOr<ChatState> build({String? conversationId, String? toUserId});
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ChatState>, ChatState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ChatState>, ChatState>,
              AsyncValue<ChatState>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(
        conversationId: _$args.conversationId,
        toUserId: _$args.toUserId,
      ),
    );
  }
}

@ProviderFor(ConversationsController)
final conversationsControllerProvider = ConversationsControllerProvider._();

final class ConversationsControllerProvider
    extends
        $AsyncNotifierProvider<ConversationsController, ConversationsState> {
  ConversationsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'conversationsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$conversationsControllerHash();

  @$internal
  @override
  ConversationsController create() => ConversationsController();
}

String _$conversationsControllerHash() =>
    r'9436b65b82cf12047aa6c795c402c10fd88f7e38';

abstract class _$ConversationsController
    extends $AsyncNotifier<ConversationsState> {
  FutureOr<ConversationsState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ConversationsState>, ConversationsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ConversationsState>, ConversationsState>,
              AsyncValue<ConversationsState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
