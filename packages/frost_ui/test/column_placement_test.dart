import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  testWidgets('a placement moves columns to one side and caps them', (tester) async {
    late EdgeInsets end, start, defaultStart;
    await tester.pumpWidget(
      Column(
        children: [
          FrostColumnPlacement(
            alignment: FrostColumnAlignment.end,
            maxWidth: 560,
            child: Builder(
              builder: (context) {
                end = FrostColumnPlacement.columnPadding(context, 900, maxWidth: FrostMetrics.readingMaxWidth);
                return const SizedBox();
              },
            ),
          ),
          FrostColumnPlacement(
            alignment: FrostColumnAlignment.start,
            maxWidth: 760,
            child: Builder(
              builder: (context) {
                start = FrostColumnPlacement.columnPadding(context, 1000, maxWidth: FrostMetrics.readingMaxWidth);
                return const SizedBox();
              },
            ),
          ),
          Builder(
            builder: (context) {
              defaultStart = FrostColumnPlacement.columnPadding(context, 1000, maxWidth: FrostMetrics.readingMaxWidth);
              return const SizedBox();
            },
          ),
        ],
      ),
    );
    final inset = FrostMetrics.browseInset(900);
    expect(end, EdgeInsets.only(left: 900 - 560 + inset, right: inset));
    expect(start, EdgeInsets.only(left: inset, right: 1000 - 760 + inset));
    expect(defaultStart, EdgeInsets.only(left: inset, right: 1000 - FrostMetrics.readingMaxWidth + inset));
    expect(defaultStart, FrostMetrics.columnPadding(1000, maxWidth: FrostMetrics.readingMaxWidth));
  });
}
