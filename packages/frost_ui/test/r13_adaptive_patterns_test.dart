import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_menu_panel.dart';
import 'support.dart';

void main() {
  testWidgets('form row reflows in its first layout at local width and mirrors RTL', (tester) async {
    for (final direction in TextDirection.values) {
      for (final width in [240.0, 600.0]) {
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: Center(
                child: SizedBox(
                  width: width,
                  child: const FrostFormRow(
                    label: SizedBox(key: ValueKey('label'), width: 160, height: 24),
                    control: SizedBox(key: ValueKey('control'), width: 160, height: 44),
                  ),
                ),
              ),
            ),
          ),
        );
        final label = tester.getRect(find.byKey(const ValueKey('label')));
        final control = tester.getRect(find.byKey(const ValueKey('control')));
        if (width == 240) {
          expect(control.top, label.bottom + FrostGap.related);
          expect(direction == TextDirection.ltr ? control.left : control.right, direction == TextDirection.ltr ? label.left : label.right);
        } else {
          expect(control.center.dy, label.center.dy);
          expect(direction == TextDirection.ltr ? control.left > label.right : control.right < label.left, true);
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('adaptive dialog uses safe available width and one action owner', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.reset);
    var actions = 0;
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 900), padding: EdgeInsets.symmetric(horizontal: 120)),
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showFrostAdaptiveDialog<void>(
                context: context,
                builder: (_) => FrostDialog(
                  title: 'Adaptive',
                  content: const Text('Content'),
                  actions: [
                    FrostDialogAction(
                      label: 'Apply',
                      isDefault: true,
                      onPressed: () {
                        actions++;
                        return true;
                      },
                    ),
                  ],
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    // A regular dialog has no Sheet drag handle.
    expect(find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 36 && w.constraints?.maxHeight == 5), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.text('Content'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch long press on a wide card and mouse context on a narrow card both work', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var actions = 0;
    Widget card() => frostTestApp(
      Center(
        child: SizedBox(
          width: 160,
          child: FrostMediaCard(
            aspectRatio: 1,
            media: const ColoredBox(color: Colors.blue),
            onPressed: () {},
            contextMenu: [FrostMenuAction('Action', onSelected: () => actions++)],
          ),
        ),
      ),
    );
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpWidget(card());
    await tester.longPress(find.byType(FrostMediaCard));
    await tester.pumpAndSettle();
    expect(find.text('Action'), findsOneWidget);
    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();
    expect(actions, 1);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(card());
    await tester.tap(find.byType(FrostMediaCard), kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuPanel), findsOneWidget);
    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();
    expect(actions, 2);
    await tester.longPress(find.byType(FrostMediaCard));
    await tester.pumpAndSettle();
    expect(find.byType(FrostMenuPanel), findsNothing);
    expect(find.text('Action'), findsOneWidget);
    await tester.tap(find.text('Action'));
    await tester.pumpAndSettle();
    expect(actions, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press callback uses input kind, independent of width', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostClickSurface(onLongPress: () => calls++, child: const SizedBox(width: 200, height: 100)),
        ),
      ),
    );
    await tester.longPress(find.byType(FrostClickSurface), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.longPress(find.byType(FrostClickSurface), kind: PointerDeviceKind.touch);
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  for (final local in [390.0, 720.0]) {
    testWidgets('default detail stage follows local portrait space at $local', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        frostTestApp(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: local,
              height: 800,
              child: const FrostDetailLayout(
                stackBelow: FrostSizeClass.large,
                stage: FrostMediaStage(aspectRatio: 1, child: SizedBox.expand(key: ValueKey('media'))),
                primary: Text('Primary'),
              ),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byKey(const ValueKey('media')));
      expect(size.height, local == 390 ? 390 : 480);
      expect(tester.takeException(), isNull);
    });
  }
}
