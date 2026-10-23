import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final sheet in [false, true]) {
    for (final scrollable in [false, true]) {
      testWidgets('error details isolate scrolling in ${sheet ? 'sheet' : 'dialog'}, scrollable=$scrollable', (tester) async {
        final lines = List.generate(120, (index) => 'Diagnostic line $index').join('\n');
        late ScrollController controller;
        Widget content() => Builder(
          builder: (context) {
            controller = PrimaryScrollController.of(context);
            final children = <Widget>[
              const Text('Intro'),
              FrostErrorDetails(details: lines, initiallyExpanded: true),
              for (var index = 0; index < 80; index++) Text('Outer row $index'),
            ];
            return scrollable ? Column(mainAxisSize: MainAxisSize.min, children: children) : ListView(children: children);
          },
        );

        await tester.pumpWidget(
          frostTestApp(
            Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  if (sheet) {
                    showFrostSheet<void>(
                      context: context,
                      title: 'Diagnostics',
                      scrollable: scrollable,
                      detents: const [FrostSheetDetent.large],
                      builder: (_) => content(),
                    );
                  } else {
                    showFrostDialog<void>(
                      context: context,
                      builder: (_) => FrostDialog(title: 'Diagnostics', scrollable: scrollable, content: content()),
                    );
                  }
                },
                child: const Text('Open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final innerFinder = find.descendant(of: find.byType(FrostErrorDetails), matching: find.byType(Scrollable)).first;
        final inner = tester.state<ScrollableState>(innerFinder);
        expect(controller.positions.length, 1);
        final outer = controller.position;
        expect(identical(inner.position, outer), false);
        expect(outer.pixels, 0);
        await tester.drag(innerFinder, const Offset(0, -180));
        await tester.pumpAndSettle();
        expect(inner.position.pixels, greaterThan(0));
        expect(outer.pixels, 0);
        final innerOffset = inner.position.pixels;
        outer.jumpTo(80);
        await tester.pump();
        expect(inner.position.pixels, innerOffset);
        expect(controller.positions.length, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
