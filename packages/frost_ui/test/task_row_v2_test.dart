import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

Widget view(Widget child, {double width = 600, double scale = 1, bool reduced = false, TextDirection direction = TextDirection.ltr}) => frostTestApp(
  MediaQuery(
    data: MediaQueryData(size: Size(width, 600), textScaler: TextScaler.linear(scale), disableAnimations: reduced),
    child: Directionality(
      textDirection: direction,
      child: Center(
        child: SizedBox(width: width, child: child),
      ),
    ),
  ),
);
Color textColor(WidgetTester tester, String label) => tester.renderObject<RenderParagraph>(find.text(label)).text.style!.color!;
Color dotColor(WidgetTester tester) {
  final dot = tester.widget<AnimatedContainer>(find.descendant(of: find.byType(FrostStatusDot), matching: find.byType(AnimatedContainer)));
  return (dot.decoration! as BoxDecoration).color!;
}

void main() {
  testWidgets('selected rich row paints shared fill and ink without a checkbox or changed activation', (tester) async {
    var selected = false;
    var calls = 0;
    StateSetter? update;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostTaskRow(title: 'Task', detail: 'Detail', status: FrostTaskStatus.running, progress: .4, selected: selected, onPressed: () => calls++);
          },
        ),
      ),
    );
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostTaskRow)));
    final rowState = tester.state(find.byType(FrostListRow));
    Color fill() => tester
        .renderObjectList<RenderDecoratedBox>(find.descendant(of: find.byType(FrostListRow), matching: find.byType(DecoratedBox)))
        .map((r) => r.decoration)
        .whereType<ShapeDecoration>()
        .first
        .color!;
    expect(fill().a, 0);
    expect(textColor(tester, 'Task'), tokens.textPrimary);
    expect(textColor(tester, 'Detail'), tokens.textSecondary);
    expect(tester.getSemantics(find.bySemanticsLabel('Task')).getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
    update!(() => selected = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(fill().a, allOf(greaterThan(0), lessThan(tokens.selectionFill.a)));
    expect(textColor(tester, 'Task'), isNot(tokens.textPrimary));
    expect(textColor(tester, 'Task'), isNot(tokens.selectionInk));
    expect(textColor(tester, 'Detail'), isNot(tokens.textSecondary));
    expect(textColor(tester, 'Detail'), isNot(tokens.selectionInk));
    await tester.pump(const Duration(milliseconds: 70));
    expect(fill(), tokens.selectionFill);
    expect(textColor(tester, 'Task'), tokens.selectionInk);
    expect(textColor(tester, 'Detail'), tokens.selectionInk);
    expect(tester.getSemantics(find.bySemanticsLabel('Task')).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    expect(find.byType(FrostCheckbox), findsNothing);
    expect(tester.widget<FrostProgressBar>(find.byType(FrostProgressBar)).value, .4);
    expect(tester.state(find.byType(FrostListRow)), same(rowState));
    await tester.tap(find.text('Task'));
    expect(calls, 1);
    update!(() => selected = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(fill().a, allOf(greaterThan(0), lessThan(tokens.selectionFill.a)));
    await tester.pumpAndSettle();
    expect(fill().a, 0);
    expect(textColor(tester, 'Task'), tokens.textPrimary);
    expect(textColor(tester, 'Detail'), tokens.textSecondary);
    expect(tester.takeException(), isNull);
  });
  for (final status in FrostTaskStatus.values) {
    testWidgets('status color, default label, progress and semantics $status', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(view(FrostTaskRow(title: 'Task', status: status, progress: .5)));
      final context = tester.element(find.byType(FrostTaskRow)), tokens = FrostThemeTokens.of(context);
      final (label, color) = switch (status) {
        FrostTaskStatus.queued => (FrostScope.labelsOf(context).taskQueued, tokens.textTertiary),
        FrostTaskStatus.running => (FrostScope.labelsOf(context).taskRunning, tokens.accentInk),
        FrostTaskStatus.paused => (FrostScope.labelsOf(context).taskPaused, tokens.cautionInk),
        FrostTaskStatus.completed => (FrostScope.labelsOf(context).taskCompleted, tokens.positiveInk),
        FrostTaskStatus.failed => (FrostScope.labelsOf(context).taskFailed, tokens.negativeInk),
        FrostTaskStatus.cancelled => (FrostScope.labelsOf(context).taskCancelled, tokens.textTertiary),
      };
      expect(dotColor(tester), color);
      expect(find.text(label), findsOneWidget);
      final progress = status == FrostTaskStatus.running || status == FrostTaskStatus.paused;
      expect(find.byType(FrostProgressBar), progress ? findsOneWidget : findsNothing);
      final node = tester.getSemantics(find.bySemanticsLabel('Task'));
      expect(node.getSemanticsData().value, contains(label));
      if (progress) expect(node.getSemanticsData().value, contains('50%'));
      expect(textColor(tester, label), status == FrostTaskStatus.failed ? tokens.negativeInk : tokens.textSecondary);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('actual title-progress-status order, text keyline, thumbnail and gaps', (tester) async {
    await tester.pumpWidget(
      view(const FrostTaskRow(title: 'Task', status: FrostTaskStatus.running, detail: '2 MB/s', progress: .3, thumbnail: SizedBox.square(dimension: 40))),
    );
    final title = tester.getRect(find.text('Task')), progress = tester.getRect(find.byType(FrostProgressBar)), detail = tester.getRect(find.text('2 MB/s'));
    expect(progress.top - title.bottom, closeTo(FrostGap.inline, .1));
    expect(detail.top - progress.bottom, closeTo(FrostGap.inline, .1));
    expect(progress.left, closeTo(title.left, .1));
    final row = find.byType(FrostListRow);
    final leading = tester.widget<FrostListRow>(row).leading!;
    expect(tester.getSize(find.byWidget(leading)), const Size(40, 40));
    expect(find.byWidget(leading), findsOneWidget, reason: 'the row keeps the exact self-sized artwork without adding its own clip');
  });
  for (final direction in TextDirection.values) {
    for (final placement in FrostTaskProgressPlacement.values) {
      testWidgets('optional thumbnail and dot-free detail/progress geometry $direction $placement', (tester) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          view(
            FrostTaskRow(
              title: 'Task',
              status: FrostTaskStatus.running,
              showsStatusDot: false,
              progressPlacement: placement,
              progress: .46,
              detail: 'Source · 1.2 / 2.6 MB · 1.8 MB/s',
              thumbnail: const SizedBox.square(dimension: 48),
            ),
            direction: direction,
          ),
        );
        final title = tester.getRect(find.text('Task'));
        final detail = tester.getRect(find.text('Source · 1.2 / 2.6 MB · 1.8 MB/s'));
        final progress = tester.getRect(find.byType(FrostProgressBar));
        expect(find.byType(FrostStatusDot), findsNothing);
        if (placement == FrostTaskProgressPlacement.belowDetail) {
          expect(detail.top - title.bottom, closeTo(FrostGap.inline, .1));
          expect(progress.top - detail.bottom, closeTo(FrostGap.inline, .1));
        } else {
          expect(progress.top - title.bottom, closeTo(FrostGap.inline, .1));
          expect(detail.top - progress.bottom, closeTo(FrostGap.inline, .1));
        }
        final rtl = direction == TextDirection.rtl;
        expect(rtl ? detail.right : detail.left, rtl ? title.right : title.left);
        expect(rtl ? progress.right : progress.left, rtl ? title.right : title.left);
        final leading = tester.widget<FrostListRow>(find.byType(FrostListRow)).leading!;
        expect(tester.getSize(find.byWidget(leading)), const Size(48, 48));
        final value = tester.getSemantics(find.bySemanticsLabel('Task')).getSemanticsData().value;
        expect(value, contains(FrostScope.labelsOf(tester.element(find.byType(FrostTaskRow))).taskRunning));
        expect(value, contains('46%'));
        semantics.dispose();
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('dot-free failure keeps negative detail and failure semantics without progress', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      view(
        const FrostTaskRow(
          title: 'Task',
          status: FrostTaskStatus.failed,
          showsStatusDot: false,
          progressPlacement: FrostTaskProgressPlacement.belowDetail,
          progress: .46,
          detail: 'Source · Connection timed out',
        ),
      ),
    );
    expect(find.byType(FrostStatusDot), findsNothing);
    expect(find.byType(FrostProgressBar), findsNothing);
    final context = tester.element(find.byType(FrostTaskRow));
    expect(textColor(tester, 'Source · Connection timed out'), FrostThemeTokens.of(context).negativeInk);
    final value = tester.getSemantics(find.bySemanticsLabel('Task')).getSemanticsData().value;
    expect(value, contains(FrostScope.labelsOf(context).taskFailed));
    expect(value, contains('Connection timed out'));
    semantics.dispose();
  });
  testWidgets('two independent visible actions and remaining actions merge into actual menu', (tester) async {
    final calls = <int>[];
    var main = 0;
    final actions = List.generate(4, (i) => FrostTaskAction(label: 'Action $i', icon: testIcons.add, onPressed: () => calls.add(i)));
    await tester.pumpWidget(
      view(
        FrostTaskRow(
          title: 'Task',
          status: FrostTaskStatus.running,
          actions: actions,
          onPressed: () => main++,
          contextMenu: [FrostMenuAction('Own', onSelected: () => calls.add(9))],
        ),
      ),
    );
    expect(find.byType(FrostButton), findsNWidgets(2));
    final semantics = tester.ensureSemantics();
    expect(find.bySemanticsLabel('Action 0'), findsWidgets);
    await tester.tap(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Action 0'));
    expect(calls, [0]);
    expect(main, 0);
    await tester.tap(find.text('Task'));
    expect(main, 1);
    await tester.tap(find.text('Task'), buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('Own'), findsOneWidget);
    expect(find.text('Action 2'), findsOneWidget);
    expect(find.text('Action 3'), findsOneWidget);
    await tester.tap(find.text('Action 3'));
    await tester.pumpAndSettle();
    expect(calls, [0, 3]);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('shared selection routes main row only and actions stay independent', (tester) async {
    final selection = FrostSelection<int>();
    addTearDown(selection.dispose);
    var opened = 0, action = 0;
    await tester.pumpWidget(
      view(
        FrostSelectionScope(
          selection: selection,
          items: const [1],
          child: FrostSelectableItem(
            item: 1,
            child: FrostTaskRow(
              title: 'Task',
              status: FrostTaskStatus.queued,
              onPressed: () => opened++,
              actions: [FrostTaskAction(label: 'Action', icon: testIcons.add, onPressed: () => action++)],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Task'));
    expect(opened, 1);
    selection.enter();
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FrostButton));
    expect(action, 1);
    expect(selection.selected, isEmpty);
    await tester.tap(find.text('Task'));
    expect(selection.selected, {1});
    expect(opened, 1);
    expect(find.byType(FrostCheckbox), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final placement in FrostTaskProgressPlacement.values) {
    testWidgets('progress presence and shared row height have intermediate frames without mount animation $placement', (tester) async {
      var status = FrostTaskStatus.queued;
      StateSetter? update;
      await tester.pumpWidget(
        view(
          StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return FrostTaskRow(title: 'Task', status: status, progress: .5, detail: 'Detail', progressPlacement: placement);
            },
          ),
        ),
      );
      final finder = find.byType(FrostListRow);
      final before = tester.getSize(finder).height;
      await tester.pump(const Duration(milliseconds: 70));
      expect(tester.getSize(finder).height, before);
      update!(() => status = FrostTaskStatus.running);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 16));
      final middle = tester.getSize(finder).height;
      await tester.pumpAndSettle();
      final after = tester.getSize(finder).height;
      expect(middle, inExclusiveRange(before, after));
      expect(after - before, closeTo(8, .1));
      update!(() => status = FrostTaskStatus.completed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getSize(finder).height, inExclusiveRange(before, after));
      await tester.pumpAndSettle();
      expect(tester.getSize(finder).height, closeTo(before, .1));
      expect(find.byType(FrostProgressBar), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failure text and status dot interpolate for 140 ms', (tester) async {
    var status = FrostTaskStatus.running;
    StateSetter? update;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostTaskRow(title: 'Task', status: status, detail: 'Detail');
          },
        ),
      ),
    );
    final context = tester.element(find.byType(FrostTaskRow)), tokens = FrostThemeTokens.of(context);
    update!(() => status = FrostTaskStatus.failed);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final color = textColor(tester, 'Detail');
    expect(color, isNot(tokens.textSecondary));
    expect(color, isNot(tokens.negativeInk));
    final dot = find.descendant(of: find.byType(FrostStatusDot), matching: find.byType(DecoratedBox));
    final decorations = tester.widgetList<DecoratedBox>(dot).map((w) => w.decoration).whereType<BoxDecoration>();
    expect(decorations.any((d) => d.color != tokens.accentInk && d.color != tokens.negativeInk), isTrue);
    await tester.pumpAndSettle();
    expect(textColor(tester, 'Detail'), tokens.negativeInk);
    expect(tester.takeException(), isNull);
  });
  for (final direction in TextDirection.values) {
    testWidgets('big text wraps fully on first frame and actions mirror $direction', (tester) async {
      await tester.pumpWidget(
        view(
          FrostTaskRow(
            title: 'A complete long task title that must wrap',
            status: FrostTaskStatus.failed,
            detail: 'A long failure description that remains readable',
            thumbnail: const SizedBox.square(dimension: 40),
            actions: [
              FrostTaskAction(label: 'Retry', icon: testIcons.add, onPressed: () {}),
              FrostTaskAction(label: 'Delete', icon: testIcons.delete, onPressed: () {}),
            ],
          ),
          width: 240,
          scale: 2,
          direction: direction,
        ),
      );
      final title = tester.renderObject<RenderParagraph>(find.textContaining('A complete'));
      expect(title.maxLines, isNull);
      expect(title.didExceedMaxLines, isFalse);
      expect(tester.getSize(find.byType(FrostListRow)).height, greaterThan(80));
      final controls = tester.getRect(find.byType(FrostButton).first), label = tester.getRect(find.textContaining('A complete'));
      expect(direction == TextDirection.ltr ? controls.left > label.left : controls.right < label.right, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('very narrow action wrap and disabled scope block all callbacks', (tester) async {
    var called = 0;
    final actions = List.generate(2, (i) => FrostTaskAction(label: 'Action $i', icon: testIcons.add, onPressed: () => called++));
    await tester.pumpWidget(
      view(
        FrostControlScope(
          enabled: false,
          child: FrostTaskRow(title: 'Task', status: FrostTaskStatus.running, progress: .2, actions: actions, onPressed: () => called++),
        ),
        width: 60,
      ),
    );
    // Controls reflow below the title inside the same painted row.
    expect(tester.getTopLeft(find.byType(FrostButton).first).dy, greaterThanOrEqualTo(tester.getBottomLeft(find.text('Task')).dy));
    expect(tester.getBottomRight(find.byType(FrostButton).last).dy, lessThanOrEqualTo(tester.getBottomRight(find.byType(FrostListRow)).dy));
    expect(tester.widgetList<FrostButton>(find.byType(FrostButton)).every((w) => w.onPressed == null), isTrue);
    await tester.tapAt(tester.getCenter(find.text('Task')));
    expect(called, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced motion height settles directly and progress updates do not remount', (tester) async {
    var progress = .2;
    StateSetter? update;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostTaskRow(title: 'Task', status: FrostTaskStatus.running, progress: progress);
          },
        ),
        reduced: true,
      ),
    );
    final state = tester.state(find.byType(FrostListRow));
    update!(() => progress = .8);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(FrostListRow)), same(state));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('ordinary progress updates retain live content at full opacity', (tester) async {
    var progress = .2;
    StateSetter? update;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostTaskRow(title: 'Task', status: FrostTaskStatus.running, progress: progress, detail: 'Detail');
          },
        ),
      ),
    );
    final state = tester.state(find.byType(FrostListRow));
    update!(() => progress = .8);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    final fade = find.descendant(of: find.byType(FrostListRow), matching: find.byType(FrostMaterialRevealTransition)).first;
    expect(tester.widget<FrostMaterialRevealTransition>(fade).opacity.value, 1);
    expect(tester.state(find.byType(FrostListRow)), same(state));
    expect(tester.getSemantics(find.bySemanticsLabel('Task')).getSemanticsData().value, contains('80%'));
    await tester.pumpAndSettle();
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
