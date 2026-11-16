import 'dart:async';

import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/errors/failure.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/features/messaging/data/realtime_gateway.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';
import 'package:icex_atlas/features/notifications/application/unread_counts.dart';
import 'package:icex_atlas/features/profiles/domain/profile.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'chat_controller.g.dart';

final _uuidRe = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

class ChatState {
  const ChatState({
    required this.other,
    required this.messages,
    required this.categoria,
    this.conversationId,
    this.otherLastReadId,
    this.hasMore = false,
    this.offline = false,
  });

  final ProfileCard other;
  final List<Message> messages;
  final Categoria categoria;
  final String? conversationId;
  final String? otherLastReadId;
  final bool hasMore;
  final bool offline;

  bool get isNew => conversationId == null;

  ChatState copyWith({
    List<Message>? messages,
    Categoria? categoria,
    String? conversationId,
    String? otherLastReadId,
    bool? hasMore,
    bool? offline,
  }) => ChatState(
    other: other,
    messages: messages ?? this.messages,
    categoria: categoria ?? this.categoria,
    conversationId: conversationId ?? this.conversationId,
    otherLastReadId: otherLastReadId ?? this.otherLastReadId,
    hasMore: hasMore ?? this.hasMore,
    offline: offline ?? this.offline,
  );

  /// Estado visible de un mensaje propio: enviando → enviado → leído (doble check).
  DeliveryStatus statusOf(Message m) {
    if (m.status == DeliveryStatus.enviando || m.status == DeliveryStatus.error) return m.status;
    final read = otherLastReadId;
    return read != null && read.compareTo(m.id) >= 0
        ? DeliveryStatus.leido
        : DeliveryStatus.enviado;
  }
}

/// Mezcla ordenada por id (UUIDv7 = orden temporal), sin duplicados; el confirmado gana.
List<Message> mergeMessages(List<Message> a, List<Message> b) {
  final byId = <String, Message>{};
  for (final m in [...a, ...b]) {
    final prev = byId[m.id];
    if (prev == null || prev.status != DeliveryStatus.enviado) byId[m.id] = m;
  }
  return byId.values.toList()..sort((x, y) => x.id.compareTo(y.id));
}

@riverpod
class ChatController extends _$ChatController {
  StreamSubscription<ConversationEvent>? _sub;
  String get _me => (ref.read(sessionControllerProvider) as SignedIn).me.userId;

  @override
  Future<ChatState> build({String? conversationId, String? toUserId}) async {
    ref.onDispose(() => _sub?.cancel());
    final repo = ref.read(messagingRepositoryProvider);
    final outbox = ref.read(messageOutboxProvider);

    var convId = conversationId;
    ProfileCard? other;
    if (convId == null && toUserId != null) {
      // Deep link mensajes?to=<perfil>: acepta user_id o slug.
      other = _uuidRe.hasMatch(toUserId)
          ? (await ref.read(profilesRepositoryProvider).getProfile(userId: toUserId)).card
          : (await ref.read(profilesRepositoryProvider).getProfile(slug: toUserId)).card;
      convId = await repo.findDirect(other.userId);
    }
    if (convId == null) {
      final pending = await outbox.pending(toUserId: other!.userId, senderId: _me);
      return ChatState(other: other, messages: pending, categoria: Categoria.networking);
    }

    final cached = await outbox.cached(convId);
    try {
      final conv = await repo.conversation(convId);
      final batch = await repo.messages(convId);
      await outbox.cache(batch.items);
      final pending = await outbox.pending(conversationId: convId, senderId: _me);
      _listen(convId);
      final state = ChatState(
        other: conv.otro,
        conversationId: convId,
        categoria: conv.categoria,
        otherLastReadId: conv.otroUltimoLeidoId,
        messages: mergeMessages(batch.items, pending),
        hasMore: batch.hasMore,
      );
      unawaited(_markRead(state));
      return state;
    } on NetworkFailure {
      if (cached.isEmpty || other == null) rethrow;
      final pending = await outbox.pending(conversationId: convId, senderId: _me);
      return ChatState(
        other: other,
        conversationId: convId,
        categoria: Categoria.networking,
        messages: mergeMessages(cached, pending),
        offline: true,
      );
    }
  }

  void _listen(String convId) {
    unawaited(_sub?.cancel());
    _sub = ref.read(realtimeGatewayProvider).conversation(convId).listen(_onEvent);
  }

  Future<void> _onEvent(ConversationEvent e) async {
    final s = state.value;
    if (s == null) return;
    switch (e) {
      case MessageCreated(:final message):
        await ref.read(messageOutboxProvider).cache([message]);
        state = AsyncData(s.copyWith(messages: mergeMessages(s.messages, [message])));
        if (message.remitenteId != _me) unawaited(_markRead(state.value!));
      case MessageRead(:final userId, :final messageId):
        if (userId != _me) state = AsyncData(s.copyWith(otherLastReadId: messageId));
      case Resubscribed():
        await catchUp();
    }
  }

  /// Tras reconectar: pide por API los mensajes posteriores al último conocido.
  Future<void> catchUp() async {
    final s = state.value;
    final convId = s?.conversationId;
    if (s == null || convId == null) return;
    final last = s.messages.where((m) => m.status != DeliveryStatus.enviando).lastOrNull?.id;
    final batch = await ref.read(messagingRepositoryProvider).messages(convId, after: last);
    await ref.read(messageOutboxProvider).cache(batch.items);
    state = AsyncData(s.copyWith(messages: mergeMessages(s.messages, batch.items), offline: false));
    unawaited(_markRead(state.value!));
  }

  Future<void> loadOlder() async {
    final s = state.value;
    final convId = s?.conversationId;
    if (s == null || convId == null || !s.hasMore || s.messages.isEmpty) return;
    final batch = await ref
        .read(messagingRepositoryProvider)
        .messages(convId, before: s.messages.first.id);
    state = AsyncData(
      s.copyWith(messages: mergeMessages(batch.items, s.messages), hasMore: batch.hasMore),
    );
  }

  /// Envío: UUIDv7 → Drift «enviando» → api.send_message → «enviado».
  Future<void> send(String text) async {
    final s = state.value;
    final body = text.trim();
    if (s == null || body.isEmpty) return;
    final outbox = ref.read(messageOutboxProvider);
    final id = ref.read(idGeneratorProvider).next();
    final local = await outbox.enqueue(
      id: id,
      senderId: _me,
      cuerpo: body,
      conversationId: s.conversationId,
      toUserId: s.isNew ? s.other.userId : null,
      categoria: s.isNew ? s.categoria : null,
    );
    state = AsyncData(s.copyWith(messages: mergeMessages(s.messages, [local])));
    await _deliver(id);
  }

  Future<void> retry(String messageId) async {
    await ref.read(messageOutboxProvider).markForRetry(messageId);
    final s = state.value!;
    state = AsyncData(
      s.copyWith(
        messages: [
          for (final m in s.messages)
            if (m.id == messageId) m.withStatus(DeliveryStatus.enviando) else m,
        ],
      ),
    );
    await _deliver(messageId);
  }

  Future<void> _deliver(String id) async {
    Message? sent;
    var failed = false;
    try {
      sent = await ref.read(messageOutboxProvider).deliver(id);
    } on AppFailure {
      failed = true;
    }
    final s = state.value!;
    if (sent != null) {
      final first = s.isNew;
      state = AsyncData(
        s.copyWith(
          conversationId: sent.conversationId,
          messages: mergeMessages(s.messages.where((m) => m.id != id).toList(), [sent]),
          offline: false,
        ),
      );
      if (first) _listen(sent.conversationId);
      ref.invalidate(conversationsControllerProvider);
    } else {
      state = AsyncData(
        s.copyWith(
          offline: !failed,
          messages: [
            for (final m in s.messages)
              if (m.id == id)
                m.withStatus(failed ? DeliveryStatus.error : DeliveryStatus.enviando)
              else
                m,
          ],
        ),
      );
    }
  }

  Future<void> setCategory(Categoria c) async {
    final s = state.value;
    if (s == null) return;
    state = AsyncData(s.copyWith(categoria: c));
    if (s.conversationId != null) {
      await ref.read(messagingRepositoryProvider).setCategory(s.conversationId!, c);
    }
  }

  Future<void> _markRead(ChatState s) async {
    final last = s.messages
        .where((m) => m.remitenteId != _me && m.status == DeliveryStatus.enviado)
        .lastOrNull;
    if (last == null || s.conversationId == null) return;
    try {
      await ref.read(messagingRepositoryProvider).markRead(s.conversationId!, last.id);
      unawaited(ref.read(unreadProvider.notifier).refresh());
    } on Object {
      // se marcará en la próxima apertura
    }
  }
}

class ConversationsState {
  const ConversationsState({
    required this.items,
    this.categoria,
    this.totalUnread = 0,
    this.nextCursor,
  });

  final List<Conversation> items;
  final Categoria? categoria;
  final int totalUnread;
  final String? nextCursor;
}

@riverpod
class ConversationsController extends _$ConversationsController {
  @override
  Future<ConversationsState> build() async {
    final session = ref.watch(sessionControllerProvider);
    if (session is SignedIn) {
      final sub = ref
          .read(realtimeGatewayProvider)
          .userEvents(session.me.userId)
          .listen((_) => ref.invalidateSelf());
      ref.onDispose(sub.cancel);
    }
    return await _load(null);
  }

  Future<ConversationsState> _load(Categoria? c) async {
    final repo = ref.read(messagingRepositoryProvider);
    final page = await repo.conversations(categoria: c);
    final unread = await repo.totalUnread();
    return ConversationsState(
      items: page.items,
      categoria: c,
      totalUnread: unread,
      nextCursor: page.nextCursor,
    );
  }

  Future<void> filter(Categoria? c) async {
    state = const AsyncLoading<ConversationsState>();
    state = await AsyncValue.guard(() => _load(c));
  }
}
