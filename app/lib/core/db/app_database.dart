import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// Mensajes propios pendientes de confirmar por el servidor (estado «enviando»/«error»).
@DataClassName('OutboxRow')
class OutboxMessages extends Table {
  TextColumn get id => text()(); // UUIDv7 generado en la app → idempotencia en send_message
  TextColumn get conversationId => text().nullable()();
  TextColumn get toUserId => text().nullable()();
  TextColumn get cuerpo => text()();
  TextColumn get categoria => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('enviando'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Últimos mensajes conocidos por conversación (lectura offline y reconexión).
@DataClassName('CachedMessageRow')
@TableIndex(name: 'cached_messages_conv', columns: {#conversationId, #id})
class CachedMessages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text()();
  TextColumn get remitenteId => text()();
  TextColumn get cuerpo => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Respuestas JSON de lectura (feed, conversaciones…) para mostrar algo sin conexión.
@DataClassName('CachedPageRow')
class CachedPages extends Table {
  TextColumn get key => text()();
  TextColumn get json => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [OutboxMessages, CachedMessages, CachedPages])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? driftDatabase(name: 'icex_atlas'));

  @override
  int get schemaVersion => 1;

  /// Al cerrar sesión no deben quedar datos del socio en el dispositivo.
  Future<void> wipe() => transaction(() async {
    for (final t in allTables) {
      await delete(t).go();
    }
  });
}
