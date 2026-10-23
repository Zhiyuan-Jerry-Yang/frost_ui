import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  testWidgets('refresh dots stay 24 by 20 in both densities', (tester) async {
    for (final density in FrostDensity.values) {
      await tester.pumpWidget(
        frostTestApp(
          const Scaffold(body: Center(child: FrostRefreshDots())),
          density: density,
        ),
      );
      await tester.pump();
      expect(tester.getSize(find.byType(FrostRefreshDots)), const Size(24, 20));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('error content uses v2 empty-state geometry in both densities', (tester) async {
    for (final density in FrostDensity.values) {
      await tester.pumpWidget(
        frostTestApp(
          Scaffold(
            body: FrostErrorContent(message: 'Failed request', onRetry: () {}, details: 'Request details'),
          ),
          density: density,
        ),
      );
      await tester.pumpAndSettle();
      final icon = find.byWidgetPredicate((widget) => widget is FrostIcon && widget.size == 28);
      final title = find.text(FrostScope.labelsOf(tester.element(find.byType(FrostErrorContent))).error);
      final message = find.text('Failed request');
      final retry = find.byWidgetPredicate((widget) => widget is FrostButton && widget.variant == FrostButtonVariant.standard);
      final details = find.byType(FrostErrorDetails);
      expect(tester.getTopLeft(title).dy - tester.getBottomLeft(icon).dy, closeTo(12, .001));
      expect(tester.getTopLeft(message).dy - tester.getBottomLeft(title).dy, closeTo(8, .001));
      expect(tester.getTopLeft(retry).dy - tester.getBottomLeft(message).dy, closeTo(16, .001));
      expect(tester.getTopLeft(details).dy - tester.getBottomLeft(retry).dy, closeTo(12, .001));
      expect(tester.takeException(), isNull);
    }
  });
}
