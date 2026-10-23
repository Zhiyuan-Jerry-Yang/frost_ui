import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/toolbar_menu_button.dart';
import 'support.dart';

// Reference geometry from phase 3 (2b61696). This deliberately retains its
// original widget composition to catch shifts that dimension-only tests miss.
Widget _stage3(FrostTextRole role) => Builder(
  builder: (context) {
    final height = FrostControlSize.compact.height(context);
    final hit = FrostDensity.of(context).targetHeight;
    final inset = FrostGap.of(context).hitInset;
    return Material(
      type: MaterialType.transparency,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: hit, minWidth: hit),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: 1,
          heightFactor: 1,
          child: FrostClickSurface(
            onTap: () {},
            feedback: FrostClickFeedback.quiet,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height, minWidth: math.max(hit, FrostControlSize.compact.iconSize + inset * 2)),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: inset, vertical: FrostGap.inline),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FrostText('Reference title', role: role, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: FrostGap.inline),
                    FrostIcon(testIcons.chevronDown, size: FrostControlSize.compact.iconSize),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
);

void main() {
  testWidgets('shared button preserves phase-3 paragraph and graphic geometry', (tester) async {
    for (final density in FrostDensity.values) {
      for (final role in [FrostTextRole.callout, FrostTextRole.headline]) {
        await tester.pumpWidget(
          frostTestApp(
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KeyedSubtree(key: const ValueKey('old'), child: _stage3(role)),
                  KeyedSubtree(
                    key: const ValueKey('new'),
                    child: FrostToolbarControl(label: 'Reference title', onPressed: () {}, chevron: true, role: role, truncates: true),
                  ),
                ],
              ),
            ),
            density: density,
          ),
        );
        Rect relative(String key, Finder child) {
          final root = find.byKey(ValueKey(key));
          final origin = tester.getTopLeft(find.descendant(of: root, matching: find.byType(FrostClickSurface)));
          return tester.getRect(find.descendant(of: root, matching: child)).shift(-origin);
        }

        expect(relative('new', find.text('Reference title')), relative('old', find.text('Reference title')), reason: '$density $role text');
        expect(relative('new', find.byType(FrostIcon)), relative('old', find.byType(FrostIcon)), reason: '$density $role icon');
        expect(tester.getSize(find.byKey(const ValueKey('new'))), tester.getSize(find.byKey(const ValueKey('old'))));
        expect(tester.takeException(), isNull);
      }
    }
  });
}
