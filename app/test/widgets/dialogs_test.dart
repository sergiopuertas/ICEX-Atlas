import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas/l10n/app_localizations.dart';
import 'package:icex_atlas/shared/widgets/dialogs.dart';

/// Regresión: «A TextEditingController was used after being disposed».
///
/// Los diálogos con campo de texto liberaban el controlador nada más resolverse
/// `showDialog`, mientras el diálogo aún se animaba al cerrarse (con el teclado abierto).
/// Estos tests cierran los diálogos y bombean toda la animación de salida: cualquier uso del
/// controlador liberado haría fallar el test con una excepción del framework.
Widget _app(Future<void> Function(BuildContext) onPressed) => MaterialApp(
  locale: const Locale('es'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: ElevatedButton(onPressed: () => onPressed(context), child: const Text('abrir')),
      ),
    ),
  ),
);

void main() {
  testWidgets('showTextPromptDialog: confirmar y cerrar sin usar un controlador liberado', (
    t,
  ) async {
    String? result;
    await t.pumpWidget(
      _app((c) async => result = await showTextPromptDialog(c, title: 'T', confirmLabel: 'OK')),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), '  hola  ');
    await t.tap(find.text('OK'));
    // Bombeo frame a frame durante la animación de salida.
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 16));
    }
    await t.pumpAndSettle();
    expect(result, 'hola');
    expect(t.takeException(), isNull);
  });

  testWidgets('showAddExperienceDialog: Guardar solo con cargo y empresa', (t) async {
    NewExperience? result;
    await t.pumpWidget(_app((c) async => result = await showAddExperienceDialog(c)));
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Guardar');
    expect(t.widget<FilledButton>(save).onPressed, isNull);
    await t.enterText(find.byType(TextField).at(0), 'Export Manager');
    await t.enterText(find.byType(TextField).at(1), 'Sener');
    await t.pump();
    expect(t.widget<FilledButton>(save).onPressed, isNotNull);
    await t.tap(save);
    await t.pumpAndSettle();
    expect(result?.cargo, 'Export Manager');
    expect(result?.empresa, 'Sener');
    expect(t.takeException(), isNull);
  });

  testWidgets('showDeleteAccountDialog: exige la palabra de confirmación', (t) async {
    String? result = 'sin tocar';
    await t.pumpWidget(
      _app((c) async => result = await showDeleteAccountDialog(c, confirmWord: 'BORRAR')),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    final del = find.widgetWithText(FilledButton, 'Eliminar');
    expect(t.widget<FilledButton>(del).onPressed, isNull);
    await t.enterText(find.byType(TextField), 'BORRAR');
    await t.pump();
    await t.tap(del);
    await t.pumpAndSettle();
    expect(result, 'BORRAR');
    expect(t.takeException(), isNull);
  });
}
