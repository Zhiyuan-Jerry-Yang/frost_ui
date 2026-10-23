import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'display_badges_v2_test.dart' show display;
import 'support.dart';

void main() {
  for (final style in FrostLabelStyle.values) {
    for (final direction in TextDirection.values) {
      testWidgets('label inherited typography and presentation $style $direction', (tester) async {
        final semantics = tester.ensureSemantics();
        await display(
          tester,
          DefaultTextStyle(
            style: const TextStyle(fontSize: 19, color: Colors.red),
            child: FrostLabel(title: 'Title 24', icon: testIcons.folder, style: style),
          ),
          width: 160,
          scale: 2,
          direction: direction,
        );
        final text = tester.renderObject<RenderParagraph>(find.text('Title 24'));
        expect(text.text.style!.fontSize, 19);
        expect(text.text.style!.color, Colors.red);
        expect(text.text.style!.fontFeatures, contains(const FontFeature.tabularFigures()));
        expect(text.maxLines, isNull);
        expect(find.byType(FrostIcon), style == FrostLabelStyle.titleOnly ? findsNothing : findsOneWidget);
        expect(findFrostTooltip('Title 24'), style == FrostLabelStyle.iconOnly ? findsOneWidget : findsNothing);
        expect(tester.getSemantics(find.byType(FrostLabel)).getSemanticsData().label, 'Title 24');
        if (style == FrostLabelStyle.titleAndIcon) {
          final icon = tester.getRect(find.byType(FrostIcon)), paragraph = tester.getRect(find.text('Title 24'));
          expect(direction == TextDirection.ltr ? paragraph.left - icon.right : icon.left - paragraph.right, 8);
        }
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
  testWidgets('toolbar leading label folds and restores on the first layout', (tester) async {
    const key = ValueKey('label');
    for (final width in [500.0, 110.0, 500.0]) {
      await display(
        tester,
        FrostToolbar(
          leading: [FrostLabel(key: key, title: 'Long toolbar title', icon: testIcons.folder)],
          trailing: [FrostToolbarItem.action(icon: testIcons.add, label: 'Add', onPressed: () {}, priority: FrostToolbarPriority.high)],
        ),
        width: width,
      );
      final label = find.byKey(key);
      final text = tester.renderObject<RenderParagraph>(find.descendant(of: label, matching: find.text('Long toolbar title')));
      expect(text.size.width, width < 200 ? 0 : greaterThan(0));
      expect(tester.getSize(label).width, width < 200 ? 18 : greaterThan(18));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('custom label respects minWidth and explicit style does not fold', (tester) async {
    await display(
      tester,
      FrostToolbar(
        trailing: [
          FrostToolbarItem.custom(
            minWidth: 44,
            overflowEntry: const FrostMenuAction('Open'),
            builder: (context) => FrostLabel(title: 'A long custom label', icon: testIcons.folder),
          ),
        ],
      ),
      width: 150,
    );
    final label = find.byType(FrostLabel);
    expect(tester.getSize(label).width, 44);
    expect(tester.getSize(find.text('A long custom label')).width, 0);
    await display(
      tester,
      FrostControlScope(
        toolbar: true,
        size: FrostControlSize.compact,
        child: FrostLabel(title: 'Fixed full label', icon: testIcons.folder, style: FrostLabelStyle.titleAndIcon),
      ),
      width: 110,
    );
    expect(tester.getSize(find.text('Fixed full label')).width, greaterThan(0));
    expect(tester.takeException(), isNull);
  });
  testWidgets('no-icon automatic label follows the toolbar title ellipsis stage', (tester) async {
    await display(tester, const FrostToolbar(leading: [FrostLabel(title: 'No icon title')]), width: 100, scale: 2);
    final paragraph = tester.renderObject<RenderParagraph>(find.text('No icon title'));
    expect(paragraph.size.width, 100);
    expect(paragraph.maxLines, 1);
    expect(paragraph.didExceedMaxLines, true);
    expect(tester.takeException(), isNull);
  });
}
