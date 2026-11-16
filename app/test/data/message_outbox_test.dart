import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/core/db/app_database.dart';
import 'package:icex_atlas/core/errors/failure.dart';
import 'package:icex_atlas/features/messaging/data/message_outbox.dart';
import 'package:icex_atlas/features/messaging/data/messaging_repository.dart';
import 'package:icex_atlas/features/messaging/domain/messaging.dart';

import '../helpers/fakes.dart';

void main() {
  late AppDatabase db;
  late FakeApiClient api;
  late MessageOutbox outbox;
  var network = true;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    network = true;
    api = FakeApiClient({
      'send_message': (p) {
        if (!network) throw const NetworkFailure();
        if (p['p_cuerpo'] == 'prohibido') throw const ForbiddenFailure('bloqueado');
        return {
          ...messageJson(p['p_id'] as String, from: 'me', cuerpo: p['p_cuerpo'] as String),
          'duplicado': false,
        };
      },
    });
    outbox = MessageOutbox(db, MessagingRepository(api));
  });

  tearDown(() => db.close());

  test('enqueue → «enviando» y deliver → «enviado» en caché', () async {
    final m = await outbox.enqueue(
      id: 'm-01',
      senderId: 'me',
      cuerpo: 'Hola',
      toUserId: 'u-2',
      categoria: Categoria.mentoria,
    );
    expect(m.status, DeliveryStatus.enviando);
    expect(await outbox.pending(toUserId: 'u-2', senderId: 'me'), hasLength(1));

    final sent = await outbox.deliver('m-01');
    expect(sent!.conversationId, 'c-1');
    expect(api.last('send_message').params['p_to'], 'u-2');
    expect(api.last('send_message').params['p_categoria'], 'mentoria');
    expect(await outbox.pending(toUserId: 'u-2', senderId: 'me'), isEmpty);
    expect((await outbox.cached('c-1')).single.cuerpo, 'Hola');
    expect(await outbox.lastKnownId('c-1'), 'm-01');
    expect(await outbox.deliver('no-existe'), isNull);
  });

  test(
    'sin red: queda pendiente y flush lo envía al reconectar (mismo id → idempotente)',
    () async {
      network = false;
      await outbox.enqueue(id: 'm-02', senderId: 'me', cuerpo: 'Offline', conversationId: 'c-1');
      expect(await outbox.deliver('m-02'), isNull);
      final pending = await outbox.pending(conversationId: 'c-1', senderId: 'me');
      expect(pending.single.status, DeliveryStatus.enviando);

      network = true;
      final sent = await outbox.flush();
      expect(sent.single.id, 'm-02');
      expect(
        api.calls.where((c) => c.name == 'send_message').map((c) => c.params['p_id']).toSet(),
        {'m-02'},
      );
      expect(api.last('send_message').params['p_conversation_id'], 'c-1');
      expect(api.last('send_message').params['p_to'], isNull);
    },
  );

  test('error definitivo → «error»; reintento manual lo reactiva', () async {
    await outbox.enqueue(id: 'm-03', senderId: 'me', cuerpo: 'prohibido', conversationId: 'c-1');
    await expectLater(outbox.deliver('m-03'), throwsA(isA<ForbiddenFailure>()));
    expect(
      (await outbox.pending(conversationId: 'c-1', senderId: 'me')).single.status,
      DeliveryStatus.error,
    );
    expect(await outbox.flush(), isEmpty, reason: 'los erróneos no se reintentan solos');
    await outbox.markForRetry('m-03');
    expect(
      (await outbox.pending(conversationId: 'c-1', senderId: 'me')).single.status,
      DeliveryStatus.enviando,
    );
  });

  test('tras maxAttempts sin red pasa a «error»', () async {
    network = false;
    await outbox.enqueue(id: 'm-04', senderId: 'me', cuerpo: 'x', conversationId: 'c-1');
    for (var i = 0; i < MessageOutbox.maxAttempts; i++) {
      await outbox.deliver('m-04');
    }
    expect(
      (await outbox.pending(conversationId: 'c-1', senderId: 'me')).single.status,
      DeliveryStatus.error,
    );
  });

  test('wipe borra todo lo local (cierre de sesión)', () async {
    await outbox.enqueue(id: 'm-05', senderId: 'me', cuerpo: 'x', conversationId: 'c-1');
    await outbox.cache([Message.fromJson(messageJson('m-00'))]);
    await db.wipe();
    expect(await outbox.pending(conversationId: 'c-1', senderId: 'me'), isEmpty);
    expect(await outbox.cached('c-1'), isEmpty);
  });
}
