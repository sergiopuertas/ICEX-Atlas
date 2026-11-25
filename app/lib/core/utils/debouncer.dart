import 'dart:async';

/// Agrupa ráfagas de llamadas en una sola: ejecuta [call] cuando pasan [delay] sin
/// llamadas nuevas.
///
/// Se usa con los eventos de Realtime: un chat activo puede recibir varios mensajes por
/// segundo, y antes cada evento lanzaba sus propias consultas (contadores, lista de
/// conversaciones, marcar leído). Con el debouncer, una ráfaga cuesta una consulta.
class Debouncer {
  Debouncer(this.delay);

  final Duration delay;
  Timer? _timer;

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  bool get isPending => _timer?.isActive ?? false;

  void dispose() => _timer?.cancel();
}

/// Retardo común para agrupar eventos de Realtime.
const realtimeBurstWindow = Duration(milliseconds: 400);
