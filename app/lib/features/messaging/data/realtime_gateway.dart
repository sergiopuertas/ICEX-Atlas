import 'dart:async';

import 'package:icex_atlas/features/messaging/domain/messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Evento de Realtime en una conversación.
sealed class ConversationEvent {
  const ConversationEvent();
}

final class MessageCreated extends ConversationEvent {
  const MessageCreated(this.message);

  final Message message;
}

final class MessageRead extends ConversationEvent {
  const MessageRead({required this.userId, required this.messageId});

  final String userId;
  final String messageId;
}

/// Reconexión: la app debe pedir por API lo posterior al último mensaje conocido.
final class Resubscribed extends ConversationEvent {
  const Resubscribed();
}

/// Canales privados de Realtime Broadcast (autorizados por RLS en realtime.messages).
abstract interface class RealtimeGateway {
  Stream<ConversationEvent> conversation(String conversationId);

  /// Canal personal `user:<id>`: avisos de no leídos y notificaciones.
  Stream<String> userEvents(String userId);
}

class SupabaseRealtimeGateway implements RealtimeGateway {
  SupabaseRealtimeGateway(this._client);

  final SupabaseClient _client;

  @override
  Stream<ConversationEvent> conversation(String conversationId) {
    late final RealtimeChannel channel;
    late final StreamController<ConversationEvent> controller;
    var wasSubscribed = false;
    controller = StreamController<ConversationEvent>(
      onListen: () {
        channel = _client
            .channel(
              'conversation:$conversationId',
              opts: const RealtimeChannelConfig(private: true),
            )
            .onBroadcast(
              event: 'message.created',
              callback: (payload) => controller.add(
                MessageCreated(
                  Message.fromJson(
                    Map<String, dynamic>.from(payload['payload'] as Map? ?? payload),
                  ),
                ),
              ),
            )
            .onBroadcast(
              event: 'message.read',
              callback: (payload) {
                final p = Map<String, dynamic>.from(payload['payload'] as Map? ?? payload);
                controller.add(
                  MessageRead(userId: p['user_id'] as String, messageId: p['message_id'] as String),
                );
              },
            )
            .subscribe((status, [error]) {
              if (status == RealtimeSubscribeStatus.subscribed) {
                if (wasSubscribed) controller.add(const Resubscribed());
                wasSubscribed = true;
              }
            });
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }

  @override
  Stream<String> userEvents(String userId) {
    late final RealtimeChannel channel;
    late final StreamController<String> controller;
    controller = StreamController<String>(
      onListen: () {
        channel = _client
            .channel('user:$userId', opts: const RealtimeChannelConfig(private: true))
            .onBroadcast(
              event: 'conversation.updated',
              callback: (_) => controller.add('conversation'),
            )
            .onBroadcast(
              event: 'notification.created',
              callback: (_) => controller.add('notification'),
            )
            .subscribe();
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }
}
