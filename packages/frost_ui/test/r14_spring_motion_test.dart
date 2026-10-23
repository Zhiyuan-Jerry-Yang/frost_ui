import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_spring_simulation.dart';
import 'package:frost_ui/src/motion/_spring_size.dart';
import 'support.dart';

void main() {
  test('geometry retargeting neither reverses nor crosses the new target', () {
    for (final spring in [FrostMotion.snappy, FrostMotion.standard, FrostMotion.gentle]) {
      for (final (start, target) in [(0.0, 1.0), (200.0, 15.0), (1.0, 1.0)]) {
        for (final velocity in [-100000.0, -200.0, 0.0, 200.0, 100000.0]) {
          final simulation = frostSpringSimulation(spring, start, target, velocity);
          var previous = start;
          expect(simulation.x(0), start);
          for (var ms = 1; ms <= 2000; ms++) {
            final value = simulation.x(ms / 1000);
            expect(value, inInclusiveRange(start < target ? start : target, start > target ? start : target));
            expect((value - previous) * (target - start), greaterThanOrEqualTo(-1e-9));
            previous = value;
          }
        }
      }
    }
  });
  testWidgets('rapid layout retargeting is continuous and bounded', (tester) async {
    var height = 40.0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return Align(
              alignment: Alignment.topLeft,
              child: FrostSpringSize(child: SizedBox(width: 100, height: height)),
            );
          },
        ),
      ),
    );
    final box = find.byType(FrostSpringSize);
    for (final target in [400.0, 60.0, 300.0, 80.0]) {
      final start = tester.getSize(box).height;
      update(() => height = target);
      await tester.pump();
      expect(tester.getSize(box).height, closeTo(start, .001));
      var previous = start;
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 8));
        final current = tester.getSize(box).height;
        expect(current, inInclusiveRange(start < target ? start : target, start > target ? start : target));
        expect((current - previous) * (target - start), greaterThanOrEqualTo(-1e-6));
        previous = current;
      }
    }
    await tester.pumpAndSettle();
    expect(tester.getSize(box).height, 80);
    expect(tester.takeException(), isNull);
  });
}
