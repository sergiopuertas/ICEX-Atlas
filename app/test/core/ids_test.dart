import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/core/utils/ids.dart';

/// Milisegundos de un UUIDv7 (los 48 primeros bits).
int msOf(String id) => int.parse(id.replaceAll('-', '').substring(0, 12), radix: 16);

void main() {
  final device = DateTime.utc(2026, 11, 24, 12);

  test('UUIDv7 válido (versión 7, variante RFC) y ordenado en el tiempo', () {
    var t = device;
    final clock = ServerClock(deviceNow: () => t);
    final gen = UuidV7Generator(clock);
    final a = gen.next();
    t = t.add(const Duration(milliseconds: 5));
    final b = gen.next();
    expect(a[14], '7');
    expect('89ab', contains(a[19]));
    expect(a.compareTo(b), lessThan(0));
  });

  test('móvil con la hora adelantada 2 h: los ids salen con la hora del servidor', () {
    final ahead = device.add(const Duration(hours: 2));
    final clock = ServerClock(deviceNow: () => ahead)..observe(device);
    expect(clock.offset, const Duration(hours: -2));
    expect(msOf(UuidV7Generator(clock).next()), device.millisecondsSinceEpoch);
  });

  test('desviaciones pequeñas (latencia, redondeo de iat) no se corrigen', () {
    final clock = ServerClock(deviceNow: () => device)
      ..observe(device.add(const Duration(seconds: 3)));
    expect(clock.offset, Duration.zero);
    expect(clock.now(), device);
  });

  test('si el reloj se arregla, la corrección desaparece', () {
    var t = device.add(const Duration(minutes: 30));
    final clock = ServerClock(deviceNow: () => t)..observe(device);
    expect(clock.offset, const Duration(minutes: -30));
    t = device;
    clock.observe(device);
    expect(clock.offset, Duration.zero);
  });
}
