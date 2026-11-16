import 'package:uuid/uuid.dart';

/// Identificadores UUIDv7 generados en la app (PostgreSQL 17 no los genera de forma nativa).
/// Ordenados en el tiempo: sirven de clave de idempotencia y de cursor de mensajes.
abstract interface class IdGenerator {
  String next();
}

class UuidV7Generator implements IdGenerator {
  const UuidV7Generator();

  static const _uuid = Uuid();

  @override
  String next() => _uuid.v7();
}
