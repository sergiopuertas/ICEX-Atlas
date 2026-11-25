import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/core/auth/auth_gateway.dart';
import 'package:icex_atlas/core/config/app_env.dart';
import 'package:icex_atlas/core/db/app_database.dart';
import 'package:icex_atlas/core/utils/ids.dart';
import 'package:icex_atlas/features/directory/data/directory_repository.dart';
import 'package:icex_atlas/features/feed/data/feed_repository.dart';
import 'package:icex_atlas/features/map/data/map_repository.dart';
import 'package:icex_atlas/features/messaging/data/message_outbox.dart';
import 'package:icex_atlas/features/messaging/data/messaging_repository.dart';
import 'package:icex_atlas/features/messaging/data/realtime_gateway.dart';
import 'package:icex_atlas/features/notifications/data/notifications_repository.dart';
import 'package:icex_atlas/features/orientador/data/orientador_repository.dart';
import 'package:icex_atlas/features/profiles/data/profiles_repository.dart';
import 'package:icex_atlas/features/settings/data/account_repository.dart';
import 'package:icex_atlas/features/social/data/social_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'providers.g.dart';

// Infraestructura (se sobreescriben en tests con dobles).

@Riverpod(keepAlive: true)
AppEnv appEnv(Ref ref) => AppEnv.fromEnvironment();

@Riverpod(keepAlive: true)
SupabaseClient supabaseClient(Ref ref) => Supabase.instance.client;

@Riverpod(keepAlive: true)
ApiClient apiClient(Ref ref) => SupabaseApiClient(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
AuthGateway authGateway(Ref ref) {
  final env = ref.watch(appEnvProvider);
  return SupabaseAuthGateway(
    ref.watch(supabaseClientProvider).auth,
    provider: env.oidcProvider,
    redirectTo: env.authRedirect,
  );
}

@Riverpod(keepAlive: true)
RealtimeGateway realtimeGateway(Ref ref) =>
    SupabaseRealtimeGateway(ref.watch(supabaseClientProvider));

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
IdGenerator idGenerator(Ref ref) => UuidV7Generator();

// Repositorios.

@Riverpod(keepAlive: true)
ProfilesRepository profilesRepository(Ref ref) => ProfilesRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
SocialRepository socialRepository(Ref ref) => SocialRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
DirectoryRepository directoryRepository(Ref ref) =>
    DirectoryRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
FeedRepository feedRepository(Ref ref) => FeedRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
MessagingRepository messagingRepository(Ref ref) =>
    MessagingRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
MessageOutbox messageOutbox(Ref ref) =>
    MessageOutbox(ref.watch(appDatabaseProvider), ref.watch(messagingRepositoryProvider));

@Riverpod(keepAlive: true)
NotificationsRepository notificationsRepository(Ref ref) =>
    NotificationsRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
MapRepository mapRepository(Ref ref) => MapRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
ClubsRepository clubsRepository(Ref ref) => ClubsRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
OrientadorRepository orientadorRepository(Ref ref) =>
    OrientadorRepository(ref.watch(apiClientProvider));

@Riverpod(keepAlive: true)
AccountRepository accountRepository(Ref ref) => AccountRepository(ref.watch(apiClientProvider));
