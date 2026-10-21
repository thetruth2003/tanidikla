import 'dart:math' as math;

import 'package:ankara_proje/app/app.dart';
import 'package:ankara_proje/app/router/app_router.dart';
import 'package:ankara_proje/features/discovery/presentation/widgets/map_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('liste ve harita profile performansı', (tester) async {
    appRouter.go(AppRoutes.discovery);
    await tester.pumpWidget(const ProviderScope(child: AnkaraServicesApp()));
    await tester.pumpAndSettle();

    final warmList = find.byType(Scrollable).last;
    await tester.fling(warmList, const Offset(0, -320), 1500);
    await tester.pumpAndSettle();
    await tester.fling(warmList, const Offset(0, 320), 1500);
    await tester.pumpAndSettle();

    final listResult = await _measureFrames('liste_kaydirma', tester, () async {
      final scrollable = find.byType(Scrollable).last;
      for (var index = 0; index < 5; index++) {
        await tester.fling(scrollable, const Offset(0, -420), 1800);
        await tester.pumpAndSettle();
        await tester.fling(scrollable, const Offset(0, 420), 1800);
        await tester.pumpAndSettle();
      }
    });

    await tester.tap(find.text('Haritada ara'));
    await tester.pumpAndSettle();
    expect(find.byType(MapPreview), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 3));
    await tester.pump();

    final map = find.byType(MapPreview);
    await _dragMap(tester, map, steps: 40, turnEvery: 20);
    await tester.pump(const Duration(milliseconds: 500));

    final mapResult = await _measureFrames(
      'harita_surukleme',
      tester,
      () async {
        await _dragMap(tester, map, steps: 120, turnEvery: 30);
      },
    );

    binding.reportData = {
      'device': 'Android emulator profile mode',
      'refresh_rate_hz': 60,
      'liste_kaydirma': listResult,
      'harita_surukleme': mapResult,
    };
  });
}

Future<Map<String, Object>> _measureFrames(
  String name,
  WidgetTester tester,
  Future<void> Function() action,
) async {
  final timings = <FrameTiming>[];
  void collect(List<FrameTiming> values) => timings.addAll(values);

  SchedulerBinding.instance.addTimingsCallback(collect);
  await action();
  SchedulerBinding.instance.removeTimingsCallback(collect);
  await tester.pump(const Duration(milliseconds: 300));

  if (timings.isEmpty) {
    throw StateError('$name için kare süresi toplanamadı.');
  }

  final totalMs =
      timings.map((timing) => timing.totalSpan.inMicroseconds / 1000).toList()
        ..sort();
  final buildMs = timings
      .map((timing) => timing.buildDuration.inMicroseconds / 1000)
      .toList();
  final rasterMs = timings
      .map((timing) => timing.rasterDuration.inMicroseconds / 1000)
      .toList();
  final frameWorkMs =
      timings
          .map(
            (timing) => math.max(
              timing.buildDuration.inMicroseconds / 1000,
              timing.rasterDuration.inMicroseconds / 1000,
            ),
          )
          .toList()
        ..sort();
  final averageFrameMs = _average(frameWorkMs);
  final averageFps = math.min(60.0, 1000 / averageFrameMs);
  final over16 = frameWorkMs.where((value) => value > 16.67).length;
  final over32 = frameWorkMs.where((value) => value > 33.33).length;

  final result = <String, Object>{
    'frames': timings.length,
    'average_fps': _round(averageFps),
    'average_frame_ms': _round(averageFrameMs),
    'p90_frame_ms': _round(_percentile(frameWorkMs, 0.90)),
    'p99_frame_ms': _round(_percentile(frameWorkMs, 0.99)),
    'average_build_ms': _round(_average(buildMs)),
    'average_raster_ms': _round(_average(rasterMs)),
    'average_total_span_ms': _round(_average(totalMs)),
    'jank_over_16_7_percent': _round(over16 * 100 / timings.length),
    'severe_jank_over_33_3_percent': _round(over32 * 100 / timings.length),
  };

  // ignore: avoid_print
  print('PERF_RESULT $name $result');
  return result;
}

double _average(List<double> values) =>
    values.reduce((first, second) => first + second) / values.length;

double _percentile(List<double> sortedValues, double percentile) {
  final index = ((sortedValues.length - 1) * percentile).round();
  return sortedValues[index];
}

double _round(double value) => double.parse(value.toStringAsFixed(2));

Future<void> _dragMap(
  WidgetTester tester,
  Finder map, {
  required int steps,
  required int turnEvery,
}) async {
  final bounds = tester.getRect(map);
  final gesture = await tester.startGesture(
    Offset(
      bounds.left + (bounds.width * 0.72),
      bounds.top + (bounds.height * 0.55),
    ),
  );

  for (var index = 0; index < steps; index++) {
    final direction = (index ~/ turnEvery).isEven ? -1.0 : 1.0;
    await gesture.moveBy(Offset(5 * direction, 1.2 * direction));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pump();
}
