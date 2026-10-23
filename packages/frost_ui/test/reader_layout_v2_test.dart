import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/_reader_anchor.dart';
import 'support.dart';

Widget header(BuildContext context, Widget settings) => SizedBox(
  height: 52,
  child: Row(
    children: [
      const Expanded(child: Text('Reader')),
      settings,
    ],
  ),
);
Widget page({
  FrostReaderSettings settings = const FrostReaderSettings(),
  ValueChanged<FrostReaderSettings>? change,
  ScrollController? controller,
  List<Widget>? slivers,
  Key? key,
}) => FrostReaderLayout(
  key: key,
  settings: settings,
  onSettingsChanged: change ?? (_) {},
  controller: controller,
  header: header,
  slivers:
      slivers ??
      [SliverList.builder(itemCount: 1000, itemBuilder: (_, index) => FrostText('Paragraph $index ${'Text for reading. ' * 20}', key: ValueKey(index)))],
);
Finder get viewport => find.byWidgetPredicate((w) => w is Viewport);
FrostReaderViewport render(WidgetTester tester) => tester.renderObject<FrostReaderViewport>(viewport.first);

void main() {
  for (var size = -2; size <= 2; size++) {
    for (var line = 0; line < 3; line++) {
      testWidgets('body reading typography $size / $line leaves other roles intact', (tester) async {
        final settings = FrostReaderSettings(textSizeStep: size, lineSpacingStep: line);
        FrostReaderSettings? inherited;
        await tester.pumpWidget(
          frostTestApp(
            page(
              settings: settings,
              slivers: [
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      inherited = FrostReaderLayout.of(context);
                      return const Column(
                        children: [
                          FrostText('body'),
                          FrostText('title', role: FrostTextRole.headline),
                          FrostRichText(text: '**rich** `code`', selectable: false),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
        final body = tester.renderObject<RenderParagraph>(find.descendant(of: find.text('body'), matching: find.byType(RichText)));
        final textSize = 15 + [-2, -1, 0, 2, 4][size + 2];
        expect(body.text.style!.fontSize, textSize);
        expect(body.text.style!.height, [1.45, 1.6, 1.8][line]);
        final rich = tester.renderObject<RenderParagraph>(find.descendant(of: find.byType(FrostRichText), matching: find.byType(RichText)).first);
        expect(rich.text.style!.fontSize, textSize);
        expect(rich.text.style!.height, [1.45, 1.6, 1.8][line]);
        expect(tester.widget<Text>(find.text('title')).style!.fontSize, 15);
        expect(inherited, settings);
      });
    }
  }
  testWidgets('reading measure is 680 excluding insets and header stays pinned', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(frostTestApp(page(controller: controller)));
    expect(tester.getSize(find.byType(FrostText).first).width, 680);
    final before = tester.getTopLeft(find.text('Reader'));
    controller.jumpTo(200);
    await tester.pump();
    expect(tester.getTopLeft(find.text('Reader')), before);
    final bar = tester.widget<FrostProgressBar>(find.byType(FrostProgressBar));
    expect(bar.value, closeTo(controller.offset / controller.position.maxScrollExtent, .0001));
    expect(tester.getSize(find.byType(FrostProgressBar)).height, 4);
  });
  for (final rich in [false, true]) {
    for (final long in [false, true]) {
      testWidgets('same-frame lazy long=$long body anchor rich=$rich', (tester) async {
        final controller = ScrollController();
        addTearDown(controller.dispose);
        final builds = <int>{};
        FrostReaderSettings current = const FrostReaderSettings();
        StateSetter? update;
        await tester.pumpWidget(
          frostTestApp(
            StatefulBuilder(
              builder: (_, setState) {
                update = setState;
                return page(
                  settings: current,
                  controller: controller,
                  slivers: [
                    SliverList.builder(
                      itemCount: 1000,
                      itemBuilder: (_, index) {
                        builds.add(index);
                        final text = '$index ${'Paragraph words for a reading position. ' * (long && index == 0 ? 3000 : 3 + index % 9)}';
                        return Padding(
                          key: ValueKey(index),
                          padding: const EdgeInsets.only(bottom: 12),
                          child: rich ? FrostRichText(text: '$text **bold words** `code` https://example.org end.', selectable: false) : FrostText(text),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        );
        controller.jumpTo(long ? 55000 : 8000);
        await tester.pump();
        for (final settings in [
          const FrostReaderSettings(textSizeStep: -2, lineSpacingStep: 0),
          const FrostReaderSettings(textSizeStep: 2, lineSpacingStep: 2),
          const FrostReaderSettings(textSizeStep: 1),
          const FrostReaderSettings(),
        ]) {
          final anchor = render(tester).readAnchor()!;
          update!(() => current = settings);
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(anchor.item.attached, isTrue);
          expect(render(tester).anchorY(anchor), closeTo(anchor.viewportY, .01));
        }
        expect(builds.length, lessThan(100));
      });
    }
  }
  testWidgets('non-text anchor retains proportional local offset in the same frame', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var current = const FrostReaderSettings();
    StateSetter? update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return page(
              settings: current,
              controller: controller,
              slivers: [
                SliverList.builder(
                  itemCount: 50,
                  itemBuilder: (context, index) => SizedBox(
                    key: ValueKey(index),
                    height: index == 0 ? (FrostReaderLayout.of(context).textSizeStep == 0 ? 1000 : 2000) : 300,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
    controller.jumpTo(300);
    await tester.pump();
    final anchor = render(tester).readAnchor()!;
    expect(anchor.paragraph, isNull);
    expect(anchor.heightFraction, closeTo(.3, .001));
    update!(() => current = const FrostReaderSettings(textSizeStep: 1));
    await tester.pump();
    expect(render(tester).anchorY(anchor), closeTo(anchor.viewportY, .01));
    expect(controller.offset, closeTo(600, .01));
  });
  for (final compact in [false, true]) {
    testWidgets('settings adaptive panel compact=$compact and controlled callbacks', (tester) async {
      tester.view.physicalSize = Size(compact ? 390 : 1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      FrostReaderSettings? changed;
      await tester.pumpWidget(frostTestApp(page(change: (settings) => changed = settings)));
      await tester.tap(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'L.readerSettings').first);
      await tester.pumpAndSettle();
      expect(find.byType(FrostPicker<int>), findsNWidgets(2));
      expect(find.text('L.textSize'), findsOneWidget);
      expect(find.text('L.lineSpacing'), findsOneWidget);
      final numeric = tester.renderObject<RenderParagraph>(find.descendant(of: find.text('19').last, matching: find.byType(RichText)));
      expect(numeric.text.style!.fontFeatures?.any((feature) => feature.feature == 'tnum'), isTrue);
      await tester.tap(find.text('19').last);
      await tester.pumpAndSettle();
      expect(changed?.textSizeStep, 2);
      if (compact) {
        expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'FrostPopoverSurface'), findsNothing);
        expect(tester.getTopLeft(find.text('L.textSize')).dy, greaterThan(300));
      } else {
        expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == 'FrostPopoverSurface'), findsOneWidget);
      }
    });
  }
  testWidgets('Space and page keys leave one reading line of overlap', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: page(controller: controller, settings: const FrostReaderSettings(textSizeStep: 2, lineSpacingStep: 2)),
        ),
      ),
    );
    await tester.tap(find.byType(FrostText).first);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pump();
    final delta = controller.position.viewportDimension - render(tester).contentTop - 19 * 1.8;
    expect(controller.offset, closeTo(delta, .01));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(controller.offset, closeTo(delta * 2, .01));
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();
    expect(controller.offset, closeTo(delta, .01));
  });
  test('settings assertions and copyWith', () {
    expect(() => FrostReaderSettings(textSizeStep: 3), throwsAssertionError);
    expect(() => FrostReaderSettings(lineSpacingStep: -1), throwsAssertionError);
    expect(const FrostReaderSettings().copyWith(textSizeStep: 1), const FrostReaderSettings(textSizeStep: 1));
  });
}
