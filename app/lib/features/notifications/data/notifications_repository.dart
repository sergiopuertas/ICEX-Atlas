import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/core/api/page.dart';
import 'package:icex_atlas/features/notifications/domain/app_notification.dart';

class NotificationsResult extends CursorPage<AppNotification> {
  const NotificationsResult({required super.items, required this.unread, super.nextCursor});

  final int unread;
}

class NotificationsRepository {
  const NotificationsRepository(this._api);

  final ApiClient _api;

  Future<NotificationsResult> list({String? cursor}) async {
    final j = await _api.rpcJson('list_notifications', {'p_cursor': cursor});
    final page = CursorPage.fromJson(j, AppNotification.fromJson);
    return NotificationsResult(
      items: page.items,
      nextCursor: page.nextCursor,
      unread: (j['no_leidas'] as num?)?.toInt() ?? 0,
    );
  }

  Future<int> markRead([List<String>? ids]) async =>
      ((await _api.rpc('mark_notifications_read', {'p_ids': ids})) as num?)?.toInt() ?? 0;

  Future<({int mensajes, int notificaciones})> unreadCounts() async {
    final j = await _api.rpcJson('unread_counts');
    return (
      mensajes: (j['mensajes'] as num?)?.toInt() ?? 0,
      notificaciones: (j['notificaciones'] as num?)?.toInt() ?? 0,
    );
  }

  Future<NotificationPreferences> preferences() async =>
      NotificationPreferences.fromJson(await _api.rpcJson('get_notification_preferences'));

  Future<NotificationPreferences> updatePreferences(NotificationPreferences p) async =>
      NotificationPreferences.fromJson(
        await _api.rpcJson('update_notification_preferences', {'p_prefs': p.toJson()}),
      );

  Future<void> registerPushToken(String token, {required String platform}) =>
      _api.rpc('register_push_token', {'p_token': token, 'p_plataforma': platform});

  Future<void> unregisterPushToken(String token) =>
      _api.rpc('unregister_push_token', {'p_token': token});
}
