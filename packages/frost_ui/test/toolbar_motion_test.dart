import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

void main() {
  testWidgets('toolbar folds crossfade after layout, settle through resize, discard snapshots and reduce immediately', (tester) async {
    tester.view.physicalSize = const Size(1800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final reduced in [false, true]) {
      final width = ValueNotifier(1600.0);
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: Center(
                child: ValueListenableBuilder(
                  valueListenable: width,
                  builder: (_, w, _) => SizedBox(
                    width: w,
                    child: FrostToolbar(
                      leading: const [Text('Collection heading')],
                      middle: const SizedBox(height: 40),
                      collapsedMiddle: const Icon(Icons.search),
                      trailing: [
                        FrostToolbarItem.action(icon: testIcons.refresh, label: 'Refresh collection', showsLabel: true, onPressed: () {}),
                        FrostToolbarItem.picker(
                          choices: const [
                            FrostPickerOption(value: 0, label: 'Latest'),
                            FrostPickerOption(value: 1, label: 'Popular'),
                            FrostPickerOption(value: 2, label: 'History'),
                          ],
                          value: 0,
                          onChanged: (_) {},
                          label: 'Mode',
                        ),
                        FrostToolbarItem.custom(
                          builder: (_) => const SizedBox(height: 36, child: Text('Custom')),
                          minWidth: 120,
                          overflowEntry: FrostMenuAction('Custom entry', onSelected: () {}),
                        ),
                        FrostToolbarItem.action(icon: testIcons.add, label: 'High', priority: FrostToolbarPriority.high, onPressed: () {}),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      void Function(Canvas) outgoing() {
        final finder = find.descendant(
          of: find.byType(FrostLayoutCrossfade),
          matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == '_OutgoingFramePainter'),
        );
        final painter = tester.widget<CustomPaint>(finder).foregroundPainter!;
        final size = tester.getSize(finder);
        return (canvas) => painter.paint(canvas, size);
      }

      expect(outgoing(), paintsNothing);
      expect(find.text('Refresh collection').hitTestable(), findsOneWidget);
      width.value = 800;
      await tester.pump();
      // Geometry changes in this very layout, before any fade tick.
      expect(find.text('Refresh collection').hitTestable(), findsNothing);
      expect(tester.getSize(find.byType(FrostToolbar)).width, 800);
      expect(find.byType(FrostLayoutCrossfade), findsOneWidget);
      List<FrostMaterialRevealTransition> transitions() => tester
          .widgetList<FrostMaterialRevealTransition>(
            find.descendant(of: find.byType(FrostLayoutCrossfade), matching: find.byType(FrostMaterialRevealTransition)),
          )
          .where((w) => w.opacity is AnimationController || w.opacity is ReverseAnimation)
          .toList();
      if (reduced) {
        expect(outgoing(), paintsNothing);
        expect(transitions().first.opacity.value, 1);
      } else {
        expect(outgoing(), paintsExactlyCountTimes(#drawImageRect, 1));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 90));
        expect(transitions().where((w) => w.opacity.value > 0 && w.opacity.value < 1).length, greaterThan(0));
        expect(outgoing(), paints..something((method, arguments) => method == #drawImageRect && (arguments[1] as Rect).size == (arguments[2] as Rect).size));
        final held = transitions().first.opacity.value;
        width.value = 799;
        await tester.pump();
        for (var i = 0; i < 6; i++) {
          width.value = 798.0 - i;
          await tester.pump(const Duration(milliseconds: 20));
          expect(transitions().first.opacity.value, held);
          expect(tester.getSize(find.byType(FrostToolbar)).width, width.value);
        }
        // Further discrete changes replace, rather than stack, old snapshots.
        for (final w in [400.0, 1600.0, 800.0]) {
          width.value = w;
          await tester.pump(const Duration(milliseconds: 20));
          expect(outgoing(), paintsExactlyCountTimes(#drawImageRect, 1));
        }
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(outgoing(), paintsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      width.dispose();
    }
  });
}
