import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('status subtitle retains first-line dot, full text and semantics $direction $scale', (tester) async {
        const label = 'Verified · mika with complete account status';
        await tester.pumpWidget(
          frostTestApp(
            Center(
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                  textDirection: direction,
                  child: SizedBox(
                    width: 200,
                    child: FrostListRow(title: 'Source', subtitle: label, subtitleStatus: FrostStatusTone.positive, onPressed: () {}),
                  ),
                ),
              ),
            ),
          ),
        );
        final dot = find.byType(FrostStatusDot);
        expect(dot, findsOneWidget);
        final shape = find.descendant(of: dot, matching: find.byType(AnimatedContainer));
        expect(tester.getSize(shape), const Size.square(8));
        final text = tester.renderObject<RenderParagraph>(find.text(label));
        final first = text
            .getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 1), boxHeightStyle: BoxHeightStyle.includeLineSpacingMiddle)
            .first
            .toRect();
        expect(tester.getCenter(shape).dy, closeTo(tester.getTopLeft(find.text(label)).dy + first.center.dy, 1));
        final gap = direction == TextDirection.ltr
            ? tester.getRect(find.text(label)).left - tester.getRect(dot).right
            : tester.getRect(dot).left - tester.getRect(find.text(label)).right;
        expect(gap, 8);
        expect(text.didExceedMaxLines, false);
        expect(tester.getSemantics(find.bySemanticsLabel('Source')).getSemanticsData().value, label);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('settings choice forwards status and includes it in accessibility', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 400,
            child: FrostSettingsSelectTile<int>.values(
              title: 'Source',
              subtitle: 'Verified',
              subtitleStatus: FrostStatusTone.positive,
              value: 1,
              values: const [1, 2],
              label: (value) => '$value',
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.byType(FrostStatusDot), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Source')).getSemanticsData().value, contains('Verified'));
  });
}
