// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appEnv)
final appEnvProvider = AppEnvProvider._();

final class AppEnvProvider extends $FunctionalProvider<AppEnv, AppEnv, AppEnv>
    with $Provider<AppEnv> {
  AppEnvProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appEnvProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appEnvHash();

  @$internal
  @override
  $ProviderElement<AppEnv> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  AppEnv create(Ref ref) {
    return appEnv(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppEnv value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<AppEnv>(value));
  }
}

String _$appEnvHash() => r'6753f6cd7309820934abb47023866db6d36ae441';

@ProviderFor(supabaseClient)
final supabaseClientProvider = SupabaseClientProvider._();

final class SupabaseClientProvider
    extends $FunctionalProvider<SupabaseClient, SupabaseClient, SupabaseClient>
    with $Provider<SupabaseClient> {
  SupabaseClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supabaseClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supabaseClientHash();

  @$internal
  @override
  $ProviderElement<SupabaseClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SupabaseClient create(Ref ref) {
    return supabaseClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupabaseClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupabaseClient>(value),
    );
  }
}

String _$supabaseClientHash() => r'3db2a4c212c7f24cea9810e376225aa1a6cab012';

@ProviderFor(apiClient)
final apiClientProvider = ApiClientProvider._();

final class ApiClientProvider extends $FunctionalProvider<ApiClient, ApiClient, ApiClient>
    with $Provider<ApiClient> {
  ApiClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'apiClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$apiClientHash();

  @$internal
  @override
  $ProviderElement<ApiClient> $createElement($ProviderPointer pointer) => $ProviderElement(pointer);

  @override
  ApiClient create(Ref ref) {
    return apiClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ApiClient value) {
    return $ProviderOverride(origin: this, providerOverride: $SyncValueProvider<ApiClient>(value));
  }
}

String _$apiClientHash() => r'5acb032bcc626accadd537d6cb9fa96a964ebcb1';

@ProviderFor(authGateway)
final authGatewayProvider = AuthGatewayProvider._();

final class AuthGatewayProvider extends $FunctionalProvider<AuthGateway, AuthGateway, AuthGateway>
    with $Provider<AuthGateway> {
  AuthGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authGatewayHash();

  @$internal
  @override
  $ProviderElement<AuthGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthGateway create(Ref ref) {
    return authGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthGateway>(value),
    );
  }
}

String _$authGatewayHash() => r'3aed19f6de2fe91e7b787d176897473084ae0062';

@ProviderFor(realtimeGateway)
final realtimeGatewayProvider = RealtimeGatewayProvider._();

final class RealtimeGatewayProvider
    extends $FunctionalProvider<RealtimeGateway, RealtimeGateway, RealtimeGateway>
    with $Provider<RealtimeGateway> {
  RealtimeGatewayProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'realtimeGatewayProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$realtimeGatewayHash();

  @$internal
  @override
  $ProviderElement<RealtimeGateway> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  RealtimeGateway create(Ref ref) {
    return realtimeGateway(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RealtimeGateway value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RealtimeGateway>(value),
    );
  }
}

String _$realtimeGatewayHash() => r'364d30092f8bab9b89bec751dbdf55a0cd2e43c3';

@ProviderFor(appDatabase)
final appDatabaseProvider = AppDatabaseProvider._();

final class AppDatabaseProvider extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  AppDatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDatabaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDatabaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return appDatabase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$appDatabaseHash() => r'59cce38d45eeaba199eddd097d8e149d66f9f3e1';

@ProviderFor(idGenerator)
final idGeneratorProvider = IdGeneratorProvider._();

final class IdGeneratorProvider extends $FunctionalProvider<IdGenerator, IdGenerator, IdGenerator>
    with $Provider<IdGenerator> {
  IdGeneratorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'idGeneratorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$idGeneratorHash();

  @$internal
  @override
  $ProviderElement<IdGenerator> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  IdGenerator create(Ref ref) {
    return idGenerator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(IdGenerator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<IdGenerator>(value),
    );
  }
}

String _$idGeneratorHash() => r'db1f00a556b20ab100c38b593333652dc28108d9';

@ProviderFor(profilesRepository)
final profilesRepositoryProvider = ProfilesRepositoryProvider._();

final class ProfilesRepositoryProvider
    extends $FunctionalProvider<ProfilesRepository, ProfilesRepository, ProfilesRepository>
    with $Provider<ProfilesRepository> {
  ProfilesRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'profilesRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$profilesRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProfilesRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ProfilesRepository create(Ref ref) {
    return profilesRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProfilesRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProfilesRepository>(value),
    );
  }
}

String _$profilesRepositoryHash() => r'85e587b0ac460c05cb8a9231c84be7f18447bb27';

@ProviderFor(socialRepository)
final socialRepositoryProvider = SocialRepositoryProvider._();

final class SocialRepositoryProvider
    extends $FunctionalProvider<SocialRepository, SocialRepository, SocialRepository>
    with $Provider<SocialRepository> {
  SocialRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'socialRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$socialRepositoryHash();

  @$internal
  @override
  $ProviderElement<SocialRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SocialRepository create(Ref ref) {
    return socialRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SocialRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SocialRepository>(value),
    );
  }
}

String _$socialRepositoryHash() => r'7953b2138f135a89e39d0fef10ebe83cd6e398da';

@ProviderFor(directoryRepository)
final directoryRepositoryProvider = DirectoryRepositoryProvider._();

final class DirectoryRepositoryProvider
    extends $FunctionalProvider<DirectoryRepository, DirectoryRepository, DirectoryRepository>
    with $Provider<DirectoryRepository> {
  DirectoryRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'directoryRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$directoryRepositoryHash();

  @$internal
  @override
  $ProviderElement<DirectoryRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DirectoryRepository create(Ref ref) {
    return directoryRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DirectoryRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DirectoryRepository>(value),
    );
  }
}

String _$directoryRepositoryHash() => r'1d1520986b049faaa20daf801eb75311036a4b16';

@ProviderFor(feedRepository)
final feedRepositoryProvider = FeedRepositoryProvider._();

final class FeedRepositoryProvider
    extends $FunctionalProvider<FeedRepository, FeedRepository, FeedRepository>
    with $Provider<FeedRepository> {
  FeedRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'feedRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$feedRepositoryHash();

  @$internal
  @override
  $ProviderElement<FeedRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FeedRepository create(Ref ref) {
    return feedRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FeedRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FeedRepository>(value),
    );
  }
}

String _$feedRepositoryHash() => r'3d3b93890d5b4386e4ae6062115968e51ae3fd46';

@ProviderFor(messagingRepository)
final messagingRepositoryProvider = MessagingRepositoryProvider._();

final class MessagingRepositoryProvider
    extends $FunctionalProvider<MessagingRepository, MessagingRepository, MessagingRepository>
    with $Provider<MessagingRepository> {
  MessagingRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messagingRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messagingRepositoryHash();

  @$internal
  @override
  $ProviderElement<MessagingRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MessagingRepository create(Ref ref) {
    return messagingRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessagingRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessagingRepository>(value),
    );
  }
}

String _$messagingRepositoryHash() => r'f0836b09e3b2b515937c57557262d6b8ae59c92e';

@ProviderFor(messageOutbox)
final messageOutboxProvider = MessageOutboxProvider._();

final class MessageOutboxProvider
    extends $FunctionalProvider<MessageOutbox, MessageOutbox, MessageOutbox>
    with $Provider<MessageOutbox> {
  MessageOutboxProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'messageOutboxProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$messageOutboxHash();

  @$internal
  @override
  $ProviderElement<MessageOutbox> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MessageOutbox create(Ref ref) {
    return messageOutbox(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MessageOutbox value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MessageOutbox>(value),
    );
  }
}

String _$messageOutboxHash() => r'fa77d5e3be3a2a66a694c42be3da987f9d41b9d8';

@ProviderFor(notificationsRepository)
final notificationsRepositoryProvider = NotificationsRepositoryProvider._();

final class NotificationsRepositoryProvider
    extends
        $FunctionalProvider<
          NotificationsRepository,
          NotificationsRepository,
          NotificationsRepository
        >
    with $Provider<NotificationsRepository> {
  NotificationsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'notificationsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$notificationsRepositoryHash();

  @$internal
  @override
  $ProviderElement<NotificationsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  NotificationsRepository create(Ref ref) {
    return notificationsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NotificationsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NotificationsRepository>(value),
    );
  }
}

String _$notificationsRepositoryHash() => r'a1c3f00a3e80571657a24cd7306a5cc09b9baff4';

@ProviderFor(mapRepository)
final mapRepositoryProvider = MapRepositoryProvider._();

final class MapRepositoryProvider
    extends $FunctionalProvider<MapRepository, MapRepository, MapRepository>
    with $Provider<MapRepository> {
  MapRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mapRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mapRepositoryHash();

  @$internal
  @override
  $ProviderElement<MapRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  MapRepository create(Ref ref) {
    return mapRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MapRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MapRepository>(value),
    );
  }
}

String _$mapRepositoryHash() => r'a399ec7552e933f0b76b61d0e79094ccedd426d4';

@ProviderFor(clubsRepository)
final clubsRepositoryProvider = ClubsRepositoryProvider._();

final class ClubsRepositoryProvider
    extends $FunctionalProvider<ClubsRepository, ClubsRepository, ClubsRepository>
    with $Provider<ClubsRepository> {
  ClubsRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clubsRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clubsRepositoryHash();

  @$internal
  @override
  $ProviderElement<ClubsRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ClubsRepository create(Ref ref) {
    return clubsRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClubsRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClubsRepository>(value),
    );
  }
}

String _$clubsRepositoryHash() => r'1d639ab126183740f17bc58ab62c5b1d056b2779';

@ProviderFor(orientadorRepository)
final orientadorRepositoryProvider = OrientadorRepositoryProvider._();

final class OrientadorRepositoryProvider
    extends $FunctionalProvider<OrientadorRepository, OrientadorRepository, OrientadorRepository>
    with $Provider<OrientadorRepository> {
  OrientadorRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'orientadorRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$orientadorRepositoryHash();

  @$internal
  @override
  $ProviderElement<OrientadorRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  OrientadorRepository create(Ref ref) {
    return orientadorRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OrientadorRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OrientadorRepository>(value),
    );
  }
}

String _$orientadorRepositoryHash() => r'f9fc589a74ec74426ca3e79ba31bd6e1340841dc';

@ProviderFor(accountRepository)
final accountRepositoryProvider = AccountRepositoryProvider._();

final class AccountRepositoryProvider
    extends $FunctionalProvider<AccountRepository, AccountRepository, AccountRepository>
    with $Provider<AccountRepository> {
  AccountRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'accountRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$accountRepositoryHash();

  @$internal
  @override
  $ProviderElement<AccountRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AccountRepository create(Ref ref) {
    return accountRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AccountRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AccountRepository>(value),
    );
  }
}

String _$accountRepositoryHash() => r'd6f9a21754bc2ca3ffc50cd8ba42ca03dbba6c68';
