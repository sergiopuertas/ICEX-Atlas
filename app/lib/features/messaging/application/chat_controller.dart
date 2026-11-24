import 'dart:async';

import 'package:icex_atlas/core/auth/session_controller.dart';
import 'package:icex_atlas/core/errors/failure.dart';
import 'package:icex_atlas/core/providers.dart';
import 'package:icex_atlas/core/utils/debouncer.dart';
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
  bool _loadingOlder = false;

  /// Marcar como leído una vez por ráfaga de mensajes entrantes (no una por mensaje).
  final _readBurst = Debouncer(realtimeBurstWindow);

  void _markReadSoon() => _readBurst(() {
    final s = ref.mounted ? state.value : null;
    if (s != null) unawaited(_markRead(s));
  });
  String get _me => ref.read(sessionUserIdProvider) ?? '';

  @override
  Future<ChatState> build({String? conversationId, String? toUserId}) async {
    ref.onDispose(() {
      _readBurst.dispose();
      unawaited(_sub?.cancel());
    });
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
    if (state.value == null) return;
    switch (e) {
      case MessageCreated(:final message):
        await ref.read(messageOutboxProvider).cache([message]);
        // Releer el estado DESPUÉS del await: si llegan dos mensajes seguidos, usar el estado
        // capturado antes perdía el primero.
        final s = ref.mounted ? state.value : null;
        if (s == null) return;
        state = AsyncData(s.copyWith(messages: mergeMessages(s.messages, [message])));
        if (message.remitenteId != _me) _markReadSoon();
      case MessageRead(:final userId, :final messageId):
        final s = state.value!;
        if (userId != _me) state = AsyncData(s.copyWith(otherLastReadId: messageId));
      case Resubscribed():
        try {
          await catchUp();
        } on Object {
          // Se reintentará en el siguiente evento o al reabrir.
        }
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
    final now = ref.mounted ? state.value : null;
    if (now == null) return;
    state = AsyncData(
      now.copyWith(messages: mergeMessages(now.messages, batch.items), offline: false),
    );
    unawaited(_markRead(state.value!));
  }

  /// Página anterior. Solo una petición a la vez: el listener de scroll la pide en cada
  /// píxel cerca del final y antes se lanzaban decenas de consultas iguales.
  Future<void> loadOlder() async {
    final s = state.value;
    final convId = s?.conversationId;
    if (_loadingOlder || s == null || convId == null || !s.hasMore || s.messages.isEmpty) return;
    _loadingOlder = true;
    try {
      final batch = await ref
          .read(messagingRepositoryProvider)
          .messages(convId, before: s.messages.first.id);
      final now = ref.mounted ? state.value : null;
      if (now == null) return;
      state = AsyncData(
        now.copyWith(messages: mergeMessages(batch.items, now.messages), hasMore: batch.hasMore),
      );
    } finally {
      _loadingOlder = false;
    }
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
    if (!ref.mounted) return;
    final now = state.value ?? s;
    state = AsyncData(now.copyWith(messages: mergeMessages(now.messages, [local])));
    await _deliver(id);
  }

  Future<void> retry(String messageId) async {
    await ref.read(messageOutboxProvider).markForRetry(messageId);
    final s = ref.mounted ? state.value : null;
    if (s == null) return;
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
    // Si se salió del chat durante el envío, el outbox ya guardó el resultado: nada que pintar.
    // (Antes: «Cannot use the Ref after it has been disposed».)
    if (!ref.mounted) return;
    final s = state.value;
    if (s == null) return;
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
    if (s == null || s.categoria == c) return;
    state = AsyncData(s.copyWith(categoria: c));
    if (s.conversationId == null) return;
    try {
      await ref.read(messagingRepositoryProvider).setCategory(s.conversationId!, c);
      if (ref.mounted) ref.invalidate(conversationsControllerProvider);
    } on Object {
      if (ref.mounted) state = AsyncData(state.value!.copyWith(categoria: s.categoria));
      rethrow;
    }
  }

  Future<void> _markRead(ChatState s) async {
    final last = s.messages
        .where((m) => m.remitenteId != _me && m.status == DeliveryStatus.enviado)
        .lastOrNull;
    if (last == null || s.conversationId == null) return;
    try {
      await ref.read(messagingRepositoryProvider).markRead(s.conversationId!, last.id);
      if (!ref.mounted) return;
      unawaited(ref.read(unreadProvider.notifier).refresh());
    } on Object {
      // se marcará en la próxima apertura
    }
  }
}

class ConversationsState {
  const ConversationsState({required this.items, this.categoria, this.nextCursor});

  final List<Conversation> items;
  final Categoria? categoria;
  final String? nextCursor;
}

@riverpod
class ConversationsController extends _$ConversationsController {
  /// Filtro elegido. Vive fuera del estado para sobrevivir a `invalidateSelf()`: antes, cada
  /// mensaje entrante (evento Realtime) recargaba la lista y borraba el filtro de categoría.
  Categoria? _categoria;

  @override
  Future<ConversationsState> build() async {
    final userId = ref.watch(sessionUserIdProvider);
    if (userId != null) {
      // Recargar la lista una vez por ráfaga de eventos, no una por mensaje.
      final burst = Debouncer(realtimeBurstWindow);
      final sub = ref
          .read(realtimeGatewayProvider)
          .userEvents(userId)
          .listen((_) => burst(ref.invalidateSelf));
      ref.onDispose(() {
        burst.dispose();
        unawaited(sub.cancel());
      });
    }
    return await _load(_categoria);
  }

  Future<ConversationsState> _load(Categoria? c) async {
    final repo = ref.read(messagingRepositoryProvider);
    // El total de no leídos lo lleva `unreadProvider` (la pantalla lo lee de ahí): antes se
    // pedía otra vez aquí, en serie tras la lista, en cada carga.
    final page = await repo.conversations(categoria: c);
    return ConversationsState(items: page.items, categoria: c, nextCursor: page.nextCursor);
  }

  Future<void> filter(Categoria? c) async {
    _categoria = c;
    // Se mantiene la lista anterior visible mientras carga (sin parpadeo a «cargando»).
    final next = await AsyncValue.guard(() => _load(c));
    if (ref.mounted && _categoria == c) state = next;
  }
}
