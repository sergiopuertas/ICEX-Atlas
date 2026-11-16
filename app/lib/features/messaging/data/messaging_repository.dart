import 'package:icex_atlas/core/api/api_client.dart';
import 'package:icex_atlas/core/api/page.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';

class MessagesBatch {
  const MessagesBatch({required this.items, required this.hasMore});

  final List<Message> items;
  final bool hasMore;
}

class SendResult {
  const SendResult({required this.message, required this.duplicate});

  final Message message;
  final bool duplicate;
}

/// Acceso remoto a la mensajería (api.*). La cola offline vive en MessageOutbox (Drift).
class MessagingRepository {
  const MessagingRepository(this._api);

  final ApiClient _api;

  Future<CursorPage<Conversation>> conversations({Categoria? categoria, String? cursor}) async {
    final j = await _api.rpcJson('list_conversations', {
      'p_categoria': categoria?.code,
      'p_cursor': cursor,
    });
    return CursorPage.fromJson(j, Conversation.fromJson);
  }

  Future<int> totalUnread() async =>
      ((await _api.rpcJson('unread_counts'))['mensajes'] as num?)?.toInt() ?? 0;

  Future<Conversation> conversation(String id) async =>
      Conversation.fromJson(await _api.rpcJson('get_conversation', {'p_conversation': id}));

  Future<String?> findDirect(String userId) async =>
      await _api.rpc('find_direct_conversation', {'p_to': userId}) as String?;

  Future<MessagesBatch> messages(String conversationId, {String? before, String? after}) async {
    final j = await _api.rpcJson('get_messages', {
      'p_conversation': conversationId,
      'p_before': before,
      'p_after': after,
    });
    return MessagesBatch(
      items: (j['items'] as List)
          .map((e) => Message.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      hasMore: j['has_more'] as bool? ?? false,
    );
  }

  /// Envío idempotente: mismo `id` (UUIDv7 generado en la app) → el servidor no duplica.
  Future<SendResult> send({
    required String id,
    required String cuerpo,
    String? conversationId,
    String? toUserId,
    Categoria? categoria,
  }) async {
    final j = await _api.rpcJson('send_message', {
      'p_id': id,
      'p_cuerpo': cuerpo,
      'p_conversation_id': conversationId,
      'p_to': toUserId,
      'p_categoria': categoria?.code,
    });
    return SendResult(message: Message.fromJson(j), duplicate: j['duplicado'] as bool? ?? false);
  }

  Future<void> markRead(String conversationId, String messageId) =>
      _api.rpc('mark_read', {'p_conversation': conversationId, 'p_message_id': messageId});

  Future<void> setCategory(String conversationId, Categoria categoria) => _api.rpc(
    'set_conversation_category',
    {'p_conversation': conversationId, 'p_categoria': categoria.code},
  );

  Future<void> heartbeat() => _api.rpc('heartbeat');
}
