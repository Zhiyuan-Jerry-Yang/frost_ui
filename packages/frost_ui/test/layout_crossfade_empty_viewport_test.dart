import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'support.dart';

void main() {
  testWidgets('empty viewport and restoration never fade in an empty frame', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(500, 400);
    addTearDown(tester.view.reset);
    final size = ValueNotifier(const Size(500, 400));
    addTearDown(size.dispose);
    await tester.pumpWidget(
      frostTestApp(
        ValueListenableBuilder<Size>(
          valueListenable: size,
          builder: (_, value, _) => MediaQuery(
            data: MediaQueryData(size: value),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: value.width,
                height: value.height,
                child: FrostLayoutCrossfade(
                  layoutIdentity: value.width < 100,
                  settleDuration: Duration.zero,
                  child: const ColoredBox(color: Colors.blue, child: Text('Retained content')),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final retained = tester.element(find.text('Retained content'));
    double opacity() => tester
        .widget<FrostMaterialRevealTransition>(
          find.descendant(of: find.byType(FrostLayoutCrossfade), matching: find.byType(FrostMaterialRevealTransition)).first,
        )
        .opacity
        .value;
    expect(opacity(), 1);
    tester.view.physicalSize = Size.zero;
    size.value = Size.zero;
    await tester.pump();
    expect(opacity(), 1);
    tester.view.physicalSize = const Size(500, 400);
    size.value = const Size(500, 400);
    await tester.pump();
    expect(opacity(), 1);
    expect(tester.element(find.text('Retained content')), same(retained));
    await tester.pump(const Duration(milliseconds: 50));
    expect(opacity(), 1);
    expect(tester.takeException(), isNull);
  });
}
