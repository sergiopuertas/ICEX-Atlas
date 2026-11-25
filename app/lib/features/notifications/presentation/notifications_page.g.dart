// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_page.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(NotificationsController)
final notificationsControllerProvider = NotificationsControllerProvider._();

final class NotificationsControllerProvider
    extends $AsyncNotifierProvider<NotificationsController, NotificationsResult> {
  NotificationsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsControllerHash();

  @$internal
  @override
  NotificationsController create() => NotificationsController();
}

String _$notificationsControllerHash() => r'dedb7d06f09c54b05d36dfd6915342b53518b9fb';

abstract class _$NotificationsController extends $AsyncNotifier<NotificationsResult> {
  FutureOr<NotificationsResult> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<NotificationsResult>, NotificationsResult>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<NotificationsResult>, NotificationsResult>,
              AsyncValue<NotificationsResult>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
