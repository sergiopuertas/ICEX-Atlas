import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icex_atlas_admin/pages.dart';

void main() {
  testWidgets('Loader muestra error y permite reintentar', (t) async {
    var calls = 0;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Loader<int>(
            load: () async {
              calls++;
              if (calls == 1) throw Exception('sin red');
              return 7;
            },
            builder: (_, v, _) => Text('valor $v'),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.textContaining('Error'), findsOneWidget);
    await t.tap(find.text('Reintentar'));
    await t.pumpAndSettle();
    expect(find.text('valor 7'), findsOneWidget);
  });
}
