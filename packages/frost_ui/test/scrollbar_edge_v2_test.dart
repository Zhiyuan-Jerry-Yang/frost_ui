import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final page in ['detail', 'browse', 'settings']) {
      testWidgets('$page scrollbar stays outside content and at pane edge $direction', (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        Widget scroll() => SingleChildScrollView(
          child: FrostContentColumn(child: SizedBox(height: 2000, child: Text('Section body'))),
        );
        final child = switch (page) {
          'detail' => const FrostDetailLayout(stage: SizedBox(), primary: Text('Information'), sections: [SizedBox(height: 2000)]),
          'browse' => FrostRefreshView(
            onRefresh: () async => true,
            builder: (context, physics, locators) => const FrostBrowseLayout(
              header: SizedBox(height: 52),
              slivers: [SliverToBoxAdapter(child: SizedBox(height: 2000))],
            ),
          ),
          _ => FrostSettingsSections.builder(labels: const ['One'], selectedIndex: 0, onSelected: (_) {}, sectionBuilder: (_, _) => scroll()),
        };
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: Builder(
                builder: (context) => Theme(
                  data: Theme.of(context).copyWith(
                    platform: TargetPlatform.windows,
                    scrollbarTheme: Theme.of(
                      context,
                    ).scrollbarTheme.copyWith(thumbVisibility: const WidgetStatePropertyAll(true), thumbColor: const WidgetStatePropertyAll(Colors.red)),
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -100));
        await tester.pumpAndSettle();
        if (page == 'browse') {
          expect(ScrollConfiguration.of(tester.element(find.byType(CustomScrollView).last)).dragDevices, contains(ui.PointerDeviceKind.mouse));
        }
        final bars = find.byWidgetPredicate((w) => w is RawScrollbar);
        expect(bars, findsWidgets);
        final bar = bars.last;
        final paint = find.descendant(
          of: bar,
          matching: find.byWidgetPredicate((widget) => widget is CustomPaint && widget.foregroundPainter is ScrollbarPainter),
        );
        final painter = tester.widget<CustomPaint>(paint).foregroundPainter! as ScrollbarPainter;
        final bounds = tester.getRect(bar);
        expect(direction == TextDirection.ltr ? bounds.right : bounds.left, direction == TextDirection.ltr ? 1440 : 0);
        expect(painter.thickness, 6);
        expect(painter.crossAxisMargin, 0);
        await tester.runAsync(() async {
          final recorder = ui.PictureRecorder();
          painter.paint(Canvas(recorder), bounds.size);
          final picture = recorder.endRecording();
          final image = await picture.toImage(bounds.width.ceil(), bounds.height.ceil());
          final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final xs = <int>{};
          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              final i = (y * image.width + x) * 4;
              if (data.getUint8(i) > 200 && data.getUint8(i + 1) < 100 && data.getUint8(i + 3) > 100) xs.add(x);
            }
          }
          expect(xs, isNotEmpty);
          expect(
            direction == TextDirection.ltr ? xs.reduce((a, b) => a > b ? a : b) : xs.reduce((a, b) => a < b ? a : b),
            direction == TextDirection.ltr ? image.width - 1 : 0,
          );
          expect(xs.length, lessThanOrEqualTo(6));
          image.dispose();
          picture.dispose();
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
