import 'package:drift/drift.dart';
import 'package:icex_atlas/core/db/app_database.dart';
import 'package:icex_atlas/core/errors/failure.dart';
import 'package:icex_atlas/features/messaging/data/messaging_repository.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';

/// Envío offline-first (arquitectura 3.5):
///  1. la app genera el UUIDv7 y guarda el mensaje en Drift como «enviando»;
///  2. llama a api.send_message (idempotente por id);
///  3. al confirmar, pasa a la caché como «enviado». Sin red, queda pendiente y se reintenta.
class MessageOutbox {
  MessageOutbox(this._db, this._remote);

  final AppDatabase _db;
  final MessagingRepository _remote;

  static const maxAttempts = 5;

  Future<Message> enqueue({
    required String id,
    required String senderId,
    required String cuerpo,
    String? conversationId,
    String? toUserId,
    Categoria? categoria,
    DateTime? now,
  }) async {
    final createdAt = now ?? DateTime.now();
    await _db
        .into(_db.outboxMessages)
        .insertOnConflictUpdate(
          OutboxMessagesCompanion.insert(
            id: id,
            conversationId: Value(conversationId),
            toUserId: Value(toUserId),
            cuerpo: cuerpo,
            categoria: Value(categoria?.code),
            createdAt: createdAt,
          ),
        );
    return Message(
      id: id,
      conversationId: conversationId ?? '',
      remitenteId: senderId,
      cuerpo: cuerpo,
      createdAt: createdAt,
      status: DeliveryStatus.enviando,
    );
  }

  /// Intenta enviar un mensaje de la cola. Devuelve el confirmado, o null si sigue pendiente.
  Future<Message?> deliver(String id) async {
    final row = await (_db.select(
      _db.outboxMessages,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) return null;
    try {
      final res = await _remote.send(
        id: row.id,
        cuerpo: row.cuerpo,
        conversationId: row.conversationId,
        toUserId: row.conversationId == null ? row.toUserId : null,
        categoria: row.categoria == null ? null : Categoria.parse(row.categoria),
      );
      await _db.transaction(() async {
        await (_db.delete(_db.outboxMessages)..where((t) => t.id.equals(id))).go();
        await cache([res.message]);
      });
      return res.message;
    } on NetworkFailure {
      await _bump(row, keepPending: true);
      return null;
    } on AppFailure {
      await _bump(row, keepPending: false);
      rethrow;
    }
  }

  /// Reintenta todo lo pendiente (al reconectar o al abrir la app).
  Future<List<Message>> flush() async {
    final pending =
        await (_db.select(_db.outboxMessages)
              ..where(
                (t) => t.status.equals('enviando') & t.attempts.isSmallerThanValue(maxAttempts),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    final sent = <Message>[];
    for (final p in pending) {
      try {
        final m = await deliver(p.id);
        if (m != null) sent.add(m);
      } on AppFailure {
        // marcado como error; el usuario puede reintentar a mano
      }
    }
    return sent;
  }

  Future<void> markForRetry(String id) =>
      (_db.update(_db.outboxMessages)..where((t) => t.id.equals(id))).write(
        const OutboxMessagesCompanion(status: Value('enviando'), attempts: Value(0)),
      );

  Future<List<Message>> pending({
    required String senderId,
    String? conversationId,
    String? toUserId,
  }) async {
    final q = _db.select(_db.outboxMessages)..orderBy([(t) => OrderingTerm.asc(t.id)]);
    if (conversationId != null) {
      q.where((t) => t.conversationId.equals(conversationId));
    } else if (toUserId != null) {
      q.where((t) => t.toUserId.equals(toUserId) & t.conversationId.isNull());
    }
    return (await q.get())
        .map(
          (r) => Message(
            id: r.id,
            conversationId: r.conversationId ?? '',
            remitenteId: senderId,
            cuerpo: r.cuerpo,
            createdAt: r.createdAt,
            status: r.status == 'error' ? DeliveryStatus.error : DeliveryStatus.enviando,
          ),
        )
        .toList();
  }

  Future<void> cache(List<Message> messages) => _db.batch((b) {
    b.insertAllOnConflictUpdate(
      _db.cachedMessages,
      messages.map(
        (m) => CachedMessagesCompanion.insert(
          id: m.id,
          conversationId: m.conversationId,
          remitenteId: m.remitenteId,
          cuerpo: m.cuerpo,
          createdAt: m.createdAt,
        ),
      ),
    );
  });

  Future<List<Message>> cached(String conversationId, {int limit = 100}) async {
    final rows =
        await (_db.select(_db.cachedMessages)
              ..where((t) => t.conversationId.equals(conversationId))
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(limit))
            .get();
    return rows.reversed
        .map(
          (r) => Message(
            id: r.id,
            conversationId: r.conversationId,
            remitenteId: r.remitenteId,
            cuerpo: r.cuerpo,
            createdAt: r.createdAt,
          ),
        )
        .toList();
  }

  /// Último id conocido: tras reconectar se piden por API los posteriores (p_after).
  Future<String?> lastKnownId(String conversationId) async {
    final row =
        await (_db.select(_db.cachedMessages)
              ..where((t) => t.conversationId.equals(conversationId))
              ..orderBy([(t) => OrderingTerm.desc(t.id)])
              ..limit(1))
            .getSingleOrNull();
    return row?.id;
  }

  Future<void> _bump(OutboxRow row, {required bool keepPending}) =>
      (_db.update(_db.outboxMessages)..where((t) => t.id.equals(row.id))).write(
        OutboxMessagesCompanion(
          attempts: Value(row.attempts + 1),
          status: Value(keepPending && row.attempts + 1 < maxAttempts ? 'enviando' : 'error'),
        ),
      );
}
