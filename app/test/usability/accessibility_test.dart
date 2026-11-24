import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app_harness.dart';
import 'layout_matrix_test.dart' show screens;

/// Guías de accesibilidad y usabilidad de Flutter sobre cada pantalla principal:
/// - zonas táctiles de al menos 48×48 dp (Android) y 44×44 pt (iOS),
/// - todo elemento tocable con una etiqueta que lea el lector de pantalla,
/// - contraste de texto WCAG AA (4,5:1; 3:1 en texto grande).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  for (final MapEntry(key: screen, value: location) in screens.entries) {
    group(screen, () {
      testWidgets('zonas táctiles Android (48 dp)', (t) async {
        final h = t.ensureSemantics();
        await pumpApp(t, appHarness(fullDemoApi()), location: location);
        await expectLater(t, meetsGuideline(androidTapTargetGuideline));
        h.dispose();
      });
      testWidgets('zonas táctiles iOS (44 pt)', (t) async {
        final h = t.ensureSemantics();
        await pumpApp(t, appHarness(fullDemoApi()), location: location);
        await expectLater(t, meetsGuideline(iOSTapTargetGuideline));
        h.dispose();
      });
      testWidgets('elementos tocables con etiqueta', (t) async {
        final h = t.ensureSemantics();
        await pumpApp(t, appHarness(fullDemoApi()), location: location);
        await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
        h.dispose();
      });
      testWidgets('contraste de texto', (t) async {
        final h = t.ensureSemantics();
        await pumpApp(t, appHarness(fullDemoApi()), location: location);
        await expectLater(t, meetsGuideline(textContrastGuideline));
        h.dispose();
      });
    });
  }
}
