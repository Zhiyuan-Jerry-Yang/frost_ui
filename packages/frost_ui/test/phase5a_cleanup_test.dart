import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_control_geometry.dart';
import 'package:frost_ui/src/foundation/_tab_metrics.dart';
import 'support.dart';

void main() {
  for (final width in [590.0, 600.0, 900.0, 1200.0]) {
    for (final rtl in [false, true]) {
      testWidgets('tab actual widths at $width start direction rtl=$rtl', (tester) async {
        final controller = TabController(length: 2, vsync: tester);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          frostTestApp(
            MediaQuery(
              data: MediaQueryData(size: Size(width, 600)),
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: FrostTabBar(
                      controller: controller,
                      tabs: [
                        const FrostTab(label: 'One'),
                        FrostTab(label: 'Two', icon: testIcons.info),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final labels = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_TabLabel');
        final firstTarget = find.ancestor(of: labels.first, matching: find.byType(InkWell)).first;
        final secondTarget = find.ancestor(of: labels.last, matching: find.byType(InkWell)).first;
        final first = tester.getRect(firstTarget), second = tester.getRect(secondTarget);
        final bar = tester.getRect(find.byType(FrostTabBar));
        if (width < 600) {
          expect(first.width, width / 2);
          expect(second.width, width / 2);
        } else {
          expect(first.width, tester.getSize(find.text('One')).width + 2 * frostTabInset);
          expect(second.width, tester.getSize(find.text('Two')).width + 2 * frostTabInset + 20 + frostTabIconGap);
          expect(rtl ? first.right : first.left, rtl ? bar.right : bar.left);
          expect(rtl ? second.right : second.left, rtl ? first.left : first.right);
          expect(first.width + second.width, lessThan(bar.width));
        }
        controller.index = 1;
        await tester.pumpAndSettle();
        expect(tester.getSize(firstTarget).width, first.width);
        expect(tester.getSize(secondTarget).width, second.width);
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final density in FrostDensity.values) {
    testWidgets('compatibility ListTile and Divider theme matches row tokens $density', (tester) async {
      await tester.pumpWidget(frostTestApp(const SizedBox(), density: density));
      final context = tester.element(find.byType(FrostToastHost));
      final theme = Theme.of(context), tokens = FrostThemeTokens.of(context);
      final tile = theme.listTileTheme;
      expect(tile.minTileHeight, FrostControlSize.regular.height(context));
      expect(tile.minVerticalPadding, frostControlGeometry(context, FrostControlSize.regular).verticalInset);
      expect(tile.minLeadingWidth, 28);
      expect(tile.horizontalTitleGap, 8);
      expect(tile.contentPadding, EdgeInsets.symmetric(horizontal: FrostGap.of(context).rowInset));
      expect(tile.titleTextStyle!.fontSize, FrostTypography.of(context).style(FrostTextRole.body).fontSize);
      expect(tile.subtitleTextStyle!.fontSize, FrostTypography.of(context).style(FrostTextRole.footnote).fontSize);
      expect(tile.titleTextStyle!.color, tokens.textPrimary);
      expect(tile.subtitleTextStyle!.color, tokens.textSecondary);
      expect(tile.iconColor, tokens.textSecondary);
      expect(tile.textColor, tokens.textPrimary);
      final corners = switch (tile.shape) {
        RoundedSuperellipseBorder(:final borderRadius) => borderRadius,
        RoundedRectangleBorder(:final borderRadius) => borderRadius,
        _ => throw StateError('shape'),
      };
      expect(corners.resolve(TextDirection.ltr).topLeft.x, FrostRadius.sm);
      expect(theme.dividerTheme.thickness, 0);
      expect(theme.dividerTheme.space, 1);
      expect(theme.dividerTheme.color, tokens.separator);
    });
  }
  test('library source has no legacy row APIs or Material row/divider constructors', () {
    final constructors = RegExp(r'\b(ListTile|ListTileTheme|Divider)\s*(?:\.\w+)?\s*\(');
    final deleted = RegExp(r'\b(FrostGroupedRows|FrostShelfHeader|FrostSwitchListTile)\b');
    final errors = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      if (constructors.hasMatch(source) || deleted.hasMatch(source)) errors.add(file.path);
    }
    expect(errors, isEmpty);
    final theme = File('lib/src/foundation/theme.dart').readAsStringSync();
    expect(theme, contains('ListTileThemeData('));
    expect(theme, contains('DividerThemeData('));
    // Both data classes are retained solely for unmigrated App compatibility.
  });
}
