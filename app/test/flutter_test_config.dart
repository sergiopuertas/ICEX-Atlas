import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Carga las fuentes reales (Sora, DM Sans) para que los golden tests se parezcan a la app,
/// e inicializa los formatos de fecha en español.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('assets/fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('DM Sans', ['DMSans-400.ttf', 'DMSans-500.ttf', 'DMSans-600.ttf', 'DMSans-700.ttf']);
  await load('Sora', ['Sora-500.ttf', 'Sora-600.ttf', 'Sora-700.ttf', 'Sora-800.ttf']);
  // Iconos Material desde el SDK de Flutter (si no, se pintan como cuadros en los golden).
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final icons = File('$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await loader.load();
  }
  await testMain();
}
