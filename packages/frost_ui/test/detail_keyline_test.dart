import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final width in [390.0, 720.0, 1440.0]) {
    for (final direction in TextDirection.values) {
      testWidgets('detail row visible icon follows the page keyline $width/$direction', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const primary = ValueKey('primary');
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: FrostDetailLayout(
                header: const SizedBox(height: 52),
                headerPlacement: FrostDetailHeaderPlacement.page,
                stage: const SizedBox(),
                primary: const SizedBox(key: primary, height: 40),
                sections: [FrostListRow(title: 'Source', icon: testIcons.link, accessory: FrostRowAccessory.external, onPressed: () {})],
              ),
            ),
          ),
        );
        final block = tester.getRect(find.byKey(primary));
        final icons = find.descendant(of: find.byType(FrostListRow), matching: find.byType(FrostIcon));
        final leading = tester.getRect(icons.first), trailing = tester.getRect(icons.last);
        if (direction == TextDirection.ltr) {
          expect(leading.left, block.left);
          expect(trailing.right, block.right);
        } else {
          expect(leading.right, block.right);
          expect(trailing.left, block.left);
        }
        // Header + exactly one section gap, never a second page inset.
        if (width >= 600) expect(block.top, 52 + FrostGap.section);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
