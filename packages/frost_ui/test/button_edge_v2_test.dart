import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final direction in TextDirection.values) {
    for (final density in FrostDensity.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('inline quiet feedback stays outside the adjacent filter $direction $density $scale', (tester) async {
          var clears = 0, resets = 0;
          await tester.pumpWidget(
            frostTestApp(
              Directionality(
                textDirection: direction,
                child: MediaQuery(
                  data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                  child: FrostContentColumn(
                    child: Wrap(
                      spacing: FrostGap.related,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FrostFilterChip(label: 'Rating', value: 'General', onClear: () => clears++),
                        FrostButton.quiet(label: 'Restore defaults', size: FrostControlSize.compact, onPressed: () => resets++),
                      ],
                    ),
                  ),
                ),
              ),
              density: density,
            ),
          );
          await tester.pumpAndSettle();
          final chip = tester.getRect(find.byType(FrostFilterChip));
          final reset = find.descendant(of: find.byType(FrostButton), matching: find.byType(FrostClickSurface));
          final feedback = tester.getRect(reset);
          expect(chip.overlaps(feedback), false);
          final resetLayout = tester.getRect(find.byType(FrostButton));
          expect(feedback.left, greaterThanOrEqualTo(resetLayout.left));
          expect(feedback.right, lessThanOrEqualTo(resetLayout.right));
          await tester.tap(reset);
          await tester.pumpAndSettle();
          expect(resets, 1);
          expect(clears, 0);
          await tester.tap(find.bySemanticsLabel('L.clearText'));
          await tester.pumpAndSettle();
          expect(resets, 1);
          expect(clears, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  for (final direction in TextDirection.values) {
    for (final grouped in [false, true]) {
      testWidgets('terminal shared row icon ink aligns with accessory and hits bleed $direction group=$grouped', (tester) async {
        var calls = 0;
        final button = FrostPresence(
          visible: true,
          child: FrostButton.icon(label: 'Copy', icon: testIcons.copy, onPressed: () => calls++),
        );
        await tester.pumpWidget(
          frostTestApp(
            Directionality(
              textDirection: direction,
              child: FrostContentColumn(
                child: Column(
                  children: [
                    const FrostListRow(title: 'External', accessory: FrostRowAccessory.external),
                    FrostListRow(
                      title: 'Copy row',
                      trailing: grouped
                          ? SizedBox(
                              width: 72,
                              child: Row(
                                children: [
                                  FrostButton.icon(label: 'Other', icon: testIcons.more, onPressed: () {}),
                                  button,
                                ],
                              ),
                            )
                          : button,
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: FrostButton.icon(
                        label: 'Explicit',
                        icon: testIcons.copy,
                        edgeAlignment: FrostButtonEdgeAlignment.end,
                        size: FrostControlSize.compact,
                        onPressed: () => calls++,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            density: FrostDensity.compact,
          ),
        );
        Rect icon(String label) => tester.getRect(find.descendant(of: find.bySemanticsLabel(label), matching: find.byType(FrostIcon)).last);
        final accessory = tester.getRect(find.descendant(of: find.byType(FrostListRow).first, matching: find.byType(FrostIcon)).last);
        for (final label in ['Copy', 'Explicit']) {
          final ink = icon(label);
          expect(direction == TextDirection.ltr ? ink.right : ink.left, closeTo(direction == TextDirection.ltr ? accessory.right : accessory.left, .001));
          final surface = tester.getRect(find.descendant(of: find.bySemanticsLabel(label), matching: find.byType(FrostClickSurface)).last);
          await tester.tapAt(Offset(direction == TextDirection.ltr ? surface.right - 1 : surface.left + 1, surface.center.dy));
          await tester.pump();
        }
        expect(calls, 2);
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('edge alignment rejects filled/media icon styles', () {
    expect(
      () => FrostButton.icon(label: 'invalid', icon: testIcons.copy, style: FrostIconButtonStyle.onMedia, edgeAlignment: FrostButtonEdgeAlignment.end),
      throwsAssertionError,
    );
  });

  for (final direction in TextDirection.values) {
    for (final edge in FrostButtonEdgeAlignment.values) {
      for (final host in ['box', 'sliver', 'card']) {
        testWidgets('edge $edge in $host preserves content, overflow hits and focus $direction', (tester) async {
          var calls = 0;
          final button = FrostButton.quiet(label: 'Edge action', edgeAlignment: edge, size: FrostControlSize.compact, onPressed: () => calls++);
          final align = edge == FrostButtonEdgeAlignment.start ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd;
          final row = Align(alignment: align, child: button);
          Widget child = switch (host) {
            'sliver' => CustomScrollView(
              slivers: [
                FrostSliverContentColumn(sliver: SliverList.list(children: [row, const SizedBox(height: 1000)])),
              ],
            ),
            'card' => FrostContentColumn(
              child: SingleChildScrollView(
                child: FrostModule(title: 'Card', content: row),
              ),
            ),
            _ => SingleChildScrollView(
              child: FrostContentColumn(child: Column(children: [row, const SizedBox(height: 1000)])),
            ),
          };
          await tester.pumpWidget(
            frostTestApp(
              Directionality(
                textDirection: direction,
                child: SizedBox(width: 500, height: 400, child: child),
              ),
              density: FrostDensity.compact,
            ),
          );
          final content = tester.getRect(find.text('Edge action'));
          final surface = tester.getRect(find.descendant(of: find.byType(FrostButton), matching: find.byType(FrostClickSurface)));
          final module = host == 'card' ? tester.getRect(find.byType(FrostModule)) : null;
          final columnInset = FrostMetrics.columnPadding(800).left;
          final keyline = module == null ? columnInset : module.left + 16;
          final endKeyline = module == null ? 800 - columnInset : module.right - 16;
          final startEdge = edge == FrostButtonEdgeAlignment.start;
          final physicalLeft = startEdge == (direction == TextDirection.ltr);
          expect(physicalLeft ? content.left : content.right, closeTo(physicalLeft ? keyline : endKeyline, .001));
          expect(surface.height, greaterThanOrEqualTo(32));
          expect(content.left - surface.left, closeTo(12, .001));
          expect(surface.right - content.right, closeTo(12, .001));
          final outside = Offset(physicalLeft ? surface.left + 2 : surface.right - 2, surface.center.dy);
          expect(outside.dx < content.left || outside.dx > content.right, isTrue);
          await tester.tapAt(outside);
          await tester.pump();
          expect(calls, 1);
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          Focus.of(tester.element(find.text('Edge action'))).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expect(tester.takeException(), isNull);
          // The shared focus painter owns the same full visual bounds as the
          // hover/press surface, rather than a narrowed text-only rectangle.
          final focus = find.descendant(
            of: find.byType(FrostButton),
            matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter.runtimeType.toString().contains('ButtonFocusPainter')),
          );
          expect(focus, findsOneWidget);
          expect(tester.getRect(focus), surface);
          final ringBounds = surface.inflate(3);
          if (module != null) {
            expect(module.contains(ringBounds.topLeft), isTrue);
            expect(module.contains(ringBounds.bottomRight), isTrue);
          }
          // Check actual ancestor paint clips, not just the button's own box.
          RenderObject current = tester.renderObject(focus);
          for (var parent = current.parent; parent != null; parent = current.parent) {
            final clip = parent.describeApproximatePaintClip(current);
            if (clip != null) {
              final global = MatrixUtils.transformRect(parent.getTransformTo(null), clip);
              expect(global.left, lessThanOrEqualTo(ringBounds.left));
              expect(global.right, greaterThanOrEqualTo(ringBounds.right));
            }
            current = parent;
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
  testWidgets('nested section action spends the module inner padding once', (tester) async {
    final header = FrostSectionHeader(title: 'Nested', actionLabel: 'Show all', onAction: () {});
    final card = FrostModule(title: 'Card', content: header);
    final content = FrostContentColumn(
      child: Align(alignment: Alignment.topCenter, child: card),
    );
    await tester.pumpWidget(frostTestApp(content));
    final module = tester.getRect(find.byType(FrostModule));
    expect(tester.getRect(find.text('Show all')).right, module.right - 16);
    expect(tester.getRect(find.text('Nested')).left, module.left + 16);
    expect(tester.takeException(), isNull);
  });

  testWidgets('null alignment retains ordinary inset and section/banner opt in', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        FrostContentColumn(
          child: Column(
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FrostButton.quiet(label: 'Ordinary', onPressed: () {}),
              ),
              FrostSectionHeader(title: 'Section', actionLabel: 'Show all', onAction: () {}),
              FrostInlineBanner(tone: FrostBannerTone.info, message: 'Message', actionLabel: 'Download', onAction: () {}),
            ],
          ),
        ),
      ),
    );
    final buttons = tester.widgetList<FrostButton>(find.byType(FrostButton)).toList();
    expect(buttons[0].edgeAlignment, isNull);
    expect(buttons[1].edgeAlignment, FrostButtonEdgeAlignment.end);
    expect(buttons[2].edgeAlignment, FrostButtonEdgeAlignment.end);
    expect(tester.takeException(), isNull);
  });
}
