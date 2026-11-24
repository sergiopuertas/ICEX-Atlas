import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';

/// Matriz de diseño: cada pantalla principal en 4 tamaños de pantalla y 3 tamaños de
/// texto del sistema (100 %, 130 % y 200 %, el máximo habitual de accesibilidad).
///
/// Falla ante cualquier excepción de interfaz: «RenderFlex overflowed» (la franja amarilla
/// y negra), errores de layout o de construcción. Es el tipo de fallo que se vio en el
/// carrusel de sugerencias (2 px de desbordamiento en un Android concreto).
const screens = <String, String?>{
  'Inicio': null,
  'Red': '/red',
  'Mensajes': '/mensajes',
  'Chat': '/mensajes/c0',
  'Orientador': '/orientador',
  'Perfil': '/perfil/javier',
  'Publicación': '/post/p0',
  'Crear publicación': '/publicar',
  'Notificaciones': '/notificaciones',
  'Novedades': '/novedades',
  'Mapa': '/mapa',
};

const textScales = [1.0, 1.3, 2.0];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  for (final MapEntry(key: screen, value: location) in screens.entries) {
    group(screen, () {
      for (final MapEntry(key: device, value: size) in Screens.all.entries) {
        for (final scale in textScales) {
          testWidgets('$device · texto ${(scale * 100).round()} %', (t) async {
            await pumpApp(
              t,
              appHarness(fullDemoApi()),
              size: size,
              textScale: scale,
              location: location,
            );
            expect(t.takeException(), isNull);
          });
        }
      }
    });
  }
}
