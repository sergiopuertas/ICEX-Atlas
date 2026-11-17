// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'map_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MapViewController)
final mapViewControllerProvider = MapViewControllerProvider._();

final class MapViewControllerProvider
    extends $NotifierProvider<MapViewController, MapState> {
  MapViewControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapViewControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapViewControllerHash();

  @$internal
  @override
  MapViewController create() => MapViewController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MapState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MapState>(value),
    );
  }
}

String _$mapViewControllerHash() => r'a3e2cb3305532880cf8c697136500a81153be318';

abstract class _$MapViewController extends $Notifier<MapState> {
  MapState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<MapState, MapState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<MapState, MapState>,
              MapState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(alumniNear)
final alumniNearProvider = AlumniNearFamily._();

final class AlumniNearProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ProfileCard>>,
          List<ProfileCard>,
          FutureOr<List<ProfileCard>>
        >
    with
        $FutureModifier<List<ProfileCard>>,
        $FutureProvider<List<ProfileCard>> {
  AlumniNearProvider._({
    required AlumniNearFamily super.from,
    required (double, double) super.argument,
  }) : super(
         retry: null,
         name: r'alumniNearProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$alumniNearHash();

  @override
  String toString() {
    return r'alumniNearProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<ProfileCard>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ProfileCard>> create(Ref ref) {
    final argument = this.argument as (double, double);
    return alumniNear(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is AlumniNearProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$alumniNearHash() => r'ad854ed3a522591646d37739ff5d7f5971b13d1e';

final class AlumniNearFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<ProfileCard>>,
          (double, double)
        > {
  AlumniNearFamily._()
    : super(
        retry: null,
        name: r'alumniNearProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  AlumniNearProvider call(double lat, double lng) =>
      AlumniNearProvider._(argument: (lat, lng), from: this);

  @override
  String toString() => r'alumniNearProvider';
}

@ProviderFor(ClubController)
final clubControllerProvider = ClubControllerFamily._();

final class ClubControllerProvider
    extends $AsyncNotifierProvider<ClubController, Club> {
  ClubControllerProvider._({
    required ClubControllerFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'clubControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$clubControllerHash();

  @override
  String toString() {
    return r'clubControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ClubController create() => ClubController();

  @override
  bool operator ==(Object other) {
    return other is ClubControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$clubControllerHash() => r'8c666fea7b1baac02ce963ba7eb4a5341b695e90';

final class ClubControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          ClubController,
          AsyncValue<Club>,
          Club,
          FutureOr<Club>,
          String
        > {
  ClubControllerFamily._()
    : super(
        retry: null,
        name: r'clubControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ClubControllerProvider call(String id) =>
      ClubControllerProvider._(argument: id, from: this);

  @override
  String toString() => r'clubControllerProvider';
}

abstract class _$ClubController extends $AsyncNotifier<Club> {
  late final _$args = ref.$arg as String;
  String get id => _$args;

  FutureOr<Club> build(String id);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<Club>, Club>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<Club>, Club>,
              AsyncValue<Club>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
