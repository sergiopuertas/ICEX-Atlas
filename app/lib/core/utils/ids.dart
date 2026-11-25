import 'package:uuid/data.dart';
import 'package:uuid/uuid.dart';

/// Identificadores UUIDv7 generados en la app (PostgreSQL 17 no los genera de forma nativa).
/// Ordenados en el tiempo: sirven de clave de idempotencia y de cursor de mensajes.
abstract interface class IdGenerator {
  String next();
}

/// Hora del servidor estimada a partir de la del móvil y la desviación observada.
///
/// El id de un mensaje lleva la hora en la que se escribe y el servidor rechaza los que
/// vienen «del futuro» (más de 5 min): un móvil con la hora mal puesta no podría escribir.
/// Por eso los ids se generan con la hora corregida: cada vez que el servidor nos dice qué
/// hora es (al emitir el token de sesión o al confirmar un mensaje), se ajusta la desviación.
class ServerClock {
  ServerClock({DateTime Function()? deviceNow}) : _deviceNow = deviceNow ?? DateTime.now;

  /// Reloj compartido por toda la app.
  static final instance = ServerClock();

  /// Por debajo de esto no se corrige: latencia de red y redondeos, no un reloj mal puesto.
  static const tolerance = Duration(seconds: 5);

  final DateTime Function() _deviceNow;
  Duration _offset = Duration.zero;

  Duration get offset => _offset;

  DateTime now() => _deviceNow().add(_offset);

  /// [serverTime]: una hora que el servidor acaba de fijar (p. ej. `created_at` de un mensaje).
  void observe(DateTime serverTime) {
    final diff = serverTime.difference(_deviceNow());
    _offset = diff.abs() > tolerance ? diff : Duration.zero;
  }
}

class UuidV7Generator implements IdGenerator {
  UuidV7Generator([ServerClock? clock]) : _clock = clock ?? ServerClock.instance;

  static const _uuid = Uuid();
  final ServerClock _clock;

  @override
  String next() => _uuid.v7(config: V7Options(_clock.now().millisecondsSinceEpoch, null));
}
