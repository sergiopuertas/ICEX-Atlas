import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/app_harness.dart';

/// Rendimiento real en un móvil: tiempos de frame al hacer scroll en Inicio, Red y Chat.
///
/// Se ejecuta en un DISPOSITIVO FÍSICO y en modo profile (en debug o en emulador los
/// tiempos no son representativos):
///
///   ./scripts/perf-app.sh        (o)
///   cd app && flutter drive --profile \
///     --driver=test_driver/perf_driver.dart \
///     --target=integration_test/scroll_performance_test.dart
///
/// Usa los mismos datos de demostración que los tests (sin backend). El resumen de cada
/// escenario queda en `app/build/<escenario>.timeline_summary.json`, y el test falla si el
/// percentil 90 de construcción o de pintado supera el presupuesto de un frame a 60 Hz.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized()
    ..framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<void> scroll(WidgetTester t, String scenario) async {
    await binding.traceAction(() async {
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 6; i++) {
        await t.fling(list, const Offset(0, -600), 2500);
        await t.pumpAndSettle();
      }
      for (var i = 0; i < 6; i++) {
        await t.fling(list, const Offset(0, 600), 2500);
        await t.pumpAndSettle();
      }
    }, reportKey: scenario);
  }

  testWidgets('Inicio: scroll del feed', (t) async {
    await t.pumpWidget(appHarness(fullDemoApi(posts: 30)));
    await settleData(t);
    await scroll(t, 'feed');
  });

  testWidgets('Red: scroll del directorio', (t) async {
    await t.pumpWidget(appHarness(fullDemoApi()));
    await settleData(t);
    await goTo(t, '/red');
    await scroll(t, 'directorio');
  });

  testWidgets('Chat: scroll de la conversación', (t) async {
    await t.pumpWidget(appHarness(fullDemoApi()));
    await settleData(t);
    await goTo(t, '/mensajes/c0');
    await scroll(t, 'chat');
  });
}
