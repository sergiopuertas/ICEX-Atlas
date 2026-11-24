import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Guarda el resumen de cada escenario y falla si se supera el presupuesto de frame.
///
/// Presupuesto: percentil 90 de construcción (UI) y de pintado (raster) por debajo de
/// 16 ms, lo necesario para 60 fps sin tirones visibles.
const _budgetMs = 16.0;

Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    final failures = <String>[];
    for (final entry in data.entries) {
      final timeline = driver.Timeline.fromJson(entry.value as Map<String, dynamic>);
      final summary = driver.TimelineSummary.summarize(timeline);
      await summary.writeTimelineToFile(entry.key, pretty: true);
      final json = summary.summaryJson;
      final build = (json['90th_percentile_frame_build_time_millis'] as num).toDouble();
      final raster = (json['90th_percentile_frame_rasterizer_time_millis'] as num).toDouble();
      // ignore: avoid_print (salida del driver en consola)
      print(
        '${entry.key}: p90 build ${build.toStringAsFixed(1)} ms · '
        'p90 raster ${raster.toStringAsFixed(1)} ms · '
        'frames perdidos ${json['missed_frame_build_budget_count']}',
      );
      if (build > _budgetMs || raster > _budgetMs) failures.add(entry.key);
    }
    if (failures.isNotEmpty) {
      throw StateError('Presupuesto de frame superado en: ${failures.join(', ')}');
    }
  },
);
