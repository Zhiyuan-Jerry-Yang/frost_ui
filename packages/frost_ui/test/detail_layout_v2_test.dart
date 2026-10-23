import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'display_badges_v2_test.dart' show display;
import 'support.dart';

void main() {
  Widget app(Widget child, {double width = 800, double local = 800, TextDirection direction = TextDirection.ltr, double dpr = 1}) => frostTestApp(
    MediaQuery(
      data: MediaQueryData(size: Size(width, 600), devicePixelRatio: dpr),
      child: Directionality(
        textDirection: direction,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: local, height: 500, child: child),
        ),
      ),
    ),
  );

  FrostDetailLayout detail({FrostSizeClass stackBelow = FrostSizeClass.medium}) => FrostDetailLayout(
    stackBelow: stackBelow,
    compactStageSizing: FrostDetailStageSizing.viewport,
    stage: SizedBox(key: ValueKey('stage')),
    header: SizedBox(height: 52, child: Text('header')),
    primary: SizedBox(height: 40, child: Text('primary')),
    actions: SizedBox(height: 30, child: Text('actions')),
    modules: [
      FrostModuleGridItem(child: SizedBox(key: ValueKey('module-a'), height: 60)),
      FrostModuleGridItem(child: SizedBox(key: ValueKey('module-b'), height: 70)),
    ],
    sections: [SizedBox(height: 600, child: Text('section'))],
    technical: SizedBox(height: 40, child: Text('technical')),
  );

  for (final direction in TextDirection.values) {
    testWidgets('page header spans both panes on the first frame and shares stage/information scroll material $direction', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final stageScroll = ScrollController();
      addTearDown(stageScroll.dispose);
      await tester.pumpWidget(
        app(
          FrostDetailLayout(
            headerPlacement: FrostDetailHeaderPlacement.page,
            header: FrostPageHeader(
              title: const Text('Full page'),
              actions: [FrostToolbarItem.action(label: 'More', icon: testIcons.more, onPressed: () {})],
            ),
            stage: CustomScrollView(
              controller: stageScroll,
              slivers: const [SliverToBoxAdapter(child: SizedBox(height: 2000))],
            ),
            primary: const Text('Information'),
            sections: const [SizedBox(height: 2000)],
          ),
          width: 1200,
          local: 1200,
          direction: direction,
        ),
      );
      final header = find.byType(FrostPageHeader);
      final glass = find.byType(FrostPinnedChromeGlass);
      expect(tester.getSize(header).height, 52);
      expect(tester.getSize(glass).width, 1200);
      expect(tester.getTopLeft(header).dy, 0);
      expect(find.byType(FrostPinnedChrome), findsOneWidget);
      final more = find.descendant(of: find.bySemanticsLabel('More'), matching: find.byType(FrostIcon));
      final icon = tester.getRect(more.last);
      final end = direction == TextDirection.ltr ? icon.right : icon.left;
      expect(end, direction == TextDirection.ltr ? 1180 : 20);
      expect(tester.widget<FrostPinnedChromeGlass>(glass).opacity, 0);
      final infoScroll = find.byType(CustomScrollView).last;
      final info = tester.state<ScrollableState>(find.descendant(of: infoScroll, matching: find.byType(Scrollable)));
      stageScroll.jumpTo(12);
      await tester.pump();
      expect(tester.widget<FrostPinnedChromeGlass>(glass).opacity, .5);
      info.position.jumpTo(24);
      await tester.pump();
      stageScroll.jumpTo(0);
      await tester.pump();
      expect(tester.widget<FrostPinnedChromeGlass>(glass).opacity, 1);
      info.position.jumpTo(0);
      await tester.pump();
      expect(tester.widget<FrostPinnedChromeGlass>(glass).opacity, 0);
      expect(tester.takeException(), isNull);
    });
  }

  for (final direction in TextDirection.values) {
    for (final placement in FrostDetailHeaderPlacement.values) {
      testWidgets('wide inset separator follows pane and measured chrome $direction $placement', (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final dpr in [1.0, 1.5, 2.0]) {
          await tester.pumpWidget(
            app(
              FrostDetailLayout(
                headerPlacement: placement,
                header: const SizedBox(height: 52),
                stage: const SizedBox(key: ValueKey('separator-stage')),
                primary: const Text('Information'),
              ),
              width: 1200,
              local: 1200,
              direction: direction,
              dpr: dpr,
            ),
          );
          final divider = find.byType(FrostDivider);
          expect(divider, findsOneWidget);
          final line = tester.getRect(divider);
          expect(line.width, closeTo(1 / dpr, .0001));
          expect(line.top, placement == FrostDetailHeaderPlacement.page ? 52 : 0);
          expect(line.bottom, 500);
          expect(direction == TextDirection.ltr ? line.left : line.right, direction == TextDirection.ltr ? 820 : 380);
          expect(tester.getSize(find.byKey(const ValueKey('separator-stage'))).width, 820);
          final tokens = FrostThemeTokens.of(tester.element(divider));
          expect(
            tester.renderObject(find.descendant(of: divider, matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget))),
            paints..line(color: tokens.separator, strokeWidth: 0),
          );
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(app(detail(), width: 390, local: 390, direction: direction));
        expect(find.byType(FrostDivider), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('page/information headers converge when stacked and retain stage, information and header State', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var width = 1200.0;
    var placement = FrostDetailHeaderPlacement.information;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return app(
            FrostDetailLayout(
              headerPlacement: placement,
              stage: const _Counter(id: 'stage'),
              primary: const _Counter(id: 'information'),
              header: const _Counter(id: 'header'),
            ),
            width: width,
            local: width,
          );
        },
      ),
    );
    final states = {
      for (final id in ['stage', 'information', 'header']) id: tester.state(find.byWidgetPredicate((w) => w is _Counter && w.id == id)),
    };
    for (final (w, p) in [
      (1200.0, FrostDetailHeaderPlacement.page),
      (390.0, FrostDetailHeaderPlacement.page),
      (390.0, FrostDetailHeaderPlacement.information),
      (1200.0, FrostDetailHeaderPlacement.information),
      (1200.0, FrostDetailHeaderPlacement.page),
    ]) {
      update(() {
        width = w;
        placement = p;
      });
      await tester.pump();
      for (final entry in states.entries) {
        expect(tester.state(find.byWidgetPredicate((w) => w is _Counter && w.id == entry.key)), same(entry.value));
      }
      expect(find.byType(FrostPinnedChromeGlass), findsOneWidget);
      expect(tester.getSize(find.byType(FrostPinnedChromeGlass)).width, w == 390 || p == FrostDetailHeaderPlacement.page ? w : 380);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  for (final direction in TextDirection.values) {
    testWidgets('detail cold wide geometry, local shrink and independent scroll $direction', (tester) async {
      await tester.pumpWidget(app(detail(), direction: direction));
      final stage = tester.getRect(find.byKey(const ValueKey('stage')));
      final info = tester.getRect(find.byType(FrostPinnedChrome));
      expect(info.width, 380);
      expect(stage.width, 420);
      expect(direction == TextDirection.ltr ? info.left == stage.right : stage.left == info.right, isTrue);
      final primary = tester.getRect(find.text('primary'));
      expect(primary.top, 52 + 24);
      final action = tester.getRect(find.ancestor(of: find.text('actions'), matching: find.byType(SizedBox)).first);
      expect(action.top, primary.top + 40 + 12);
      final module = tester.getRect(find.byKey(const ValueKey('module-a')));
      expect(module.top, action.bottom + 24);
      expect(tester.getRect(find.byKey(const ValueKey('module-b'))).top, module.top);
      expect(tester.getRect(find.text('section')).top, module.bottom + 24);
      await tester.dragFrom(Offset(info.center.dx, 350), const Offset(0, -240));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(const ValueKey('stage'))), stage);
      expect(tester.getTopLeft(find.text('primary', skipOffstage: false)).dy, lessThan(primary.top));
      expect(tester.getTopLeft(find.text('header')).dy, 0);
      await tester.pumpWidget(app(detail(stackBelow: FrostSizeClass.compact), local: 500, direction: direction));
      expect(tester.getSize(find.byType(FrostPinnedChrome)).width, 260);
      expect(tester.getSize(find.byKey(const ValueKey('stage'))).width, 240);
      await tester.pumpWidget(app(detail(stackBelow: FrostSizeClass.compact), local: 150, direction: direction));
      expect(tester.getSize(find.byKey(const ValueKey('stage'))).width, 150);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(app(detail(), direction: direction));
      expect(tester.getSize(find.byType(FrostPinnedChrome)).width, 380);
    });
  }
  testWidgets('compact stage is a finite 60 percent slot and scrolls together under pinned header', (tester) async {
    await tester.pumpWidget(app(detail(), width: 390, local: 390));
    expect(tester.getSize(find.byKey(const ValueKey('stage'))).height, 300);
    expect(tester.getTopLeft(find.byKey(const ValueKey('stage'))).dy, 52);
    expect(tester.getTopLeft(find.text('primary')).dy, 52 + 300 + 24);
    await tester.dragFrom(const Offset(195, 202), const Offset(0, -180));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('stage'))).dy, lessThan(52));
    expect(tester.getTopLeft(find.text('primary')).dy, lessThan(376));
    expect(tester.getTopLeft(find.text('header')).dy, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stage and information State survive repeated mode changes and content updates', (tester) async {
    var width = 800.0;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (_, state) {
          update = state;
          return app(
            const FrostDetailLayout(
              stage: _Counter(id: 'stage'),
              primary: _Counter(id: 'info'),
            ),
            width: width,
            local: width,
          );
        },
      ),
    );
    await tester.tap(find.text('stage 0'));
    await tester.tap(find.text('info 0'));
    await tester.pump();
    final stage = tester.state(find.byWidgetPredicate((w) => w is _Counter && w.id == 'stage'));
    final info = tester.state(find.byWidgetPredicate((w) => w is _Counter && w.id == 'info'));
    for (final next in [390.0, 800.0, 390.0, 800.0]) {
      update(() => width = next);
      await tester.pump();
      expect(tester.state(find.byWidgetPredicate((w) => w is _Counter && w.id == 'stage')), same(stage));
      expect(tester.state(find.byWidgetPredicate((w) => w is _Counter && w.id == 'info')), same(info));
      await tester.pumpAndSettle();
      expect(find.text('stage 1'), findsOneWidget);
      expect(find.text('info 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('optional threshold stacks medium on the cold frame and preserves State', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var width = 720.0;
    late StateSetter update;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (_, setState) {
          update = setState;
          return app(
            const FrostDetailLayout(
              stackBelow: FrostSizeClass.expanded,
              compactStageSizing: FrostDetailStageSizing.viewport,
              stage: _Counter(id: 'stage'),
              primary: _Counter(id: 'info'),
              header: SizedBox(height: 52),
            ),
            width: width,
            local: width,
          );
        },
      ),
    );
    final stage = tester.state(find.byWidgetPredicate((w) => w is _Counter && w.id == 'stage'));
    final info = tester.state(find.byWidgetPredicate((w) => w is _Counter && w.id == 'info'));
    expect(tester.getSize(find.byWidgetPredicate((w) => w is _Counter && w.id == 'stage')).height, 300);
    expect(tester.getTopLeft(find.byWidgetPredicate((w) => w is _Counter && w.id == 'info')).dy, 52 + 300 + 24);
    await tester.tap(find.text('stage 0'));
    await tester.tap(find.text('info 0'));
    await tester.pump();
    for (final next in [1024.0, 720.0, 390.0, 1024.0]) {
      update(() => width = next);
      await tester.pump();
      expect(tester.state(find.byWidgetPredicate((w) => w is _Counter && w.id == 'stage')), same(stage));
      expect(tester.state(find.byWidgetPredicate((w) => w is _Counter && w.id == 'info')), same(info));
      await tester.pumpAndSettle();
      expect(find.text('stage 1'), findsOneWidget);
      expect(find.text('info 1'), findsOneWidget);
      if (next < 900) {
        expect(tester.getSize(find.byWidgetPredicate((w) => w is _Counter && w.id == 'stage')).height, 300);
      } else {
        expect(tester.getSize(find.byType(FrostPinnedChrome)).width, 380);
      }
      expect(tester.takeException(), isNull);
    }
  });

  for (final width in [390.0, 1200.0]) {
    testWidgets('detail content replacement clamps a scrolled pane safely at $width', (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var height = 1600.0;
      ImageProvider? backdrop;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return app(
              FrostDetailLayout(
                headerPlacement: FrostDetailHeaderPlacement.page,
                header: const SizedBox(height: 52),
                stage: const SizedBox(),
                primary: const Text('Information'),
                sections: [SizedBox(height: height)],
                backdrop: backdrop,
              ),
              width: width,
              local: width,
            );
          },
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable));
      final state = tester.state<ScrollableState>(scrollable);
      state.position.jumpTo(state.position.maxScrollExtent - 10);
      await tester.pumpAndSettle();
      expect(state.position.pixels, greaterThan(0));
      update(() {
        height = 40;
        backdrop = MemoryImage(Uint8List.fromList(kTransparentImage));
      });
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      final current = tester.state<ScrollableState>(scrollable);
      expect(current, same(state));
      expect(current.position.pixels, inInclusiveRange(current.position.minScrollExtent, current.position.maxScrollExtent));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('normal surface, image backdrop and absent blocks have no phantom gaps', (tester) async {
    final image = MemoryImage(Uint8List.fromList(kTransparentImage));
    await tester.pumpWidget(
      app(FrostDetailLayout(stage: const SizedBox(), primary: const Text('primary'), technical: const Text('technical'), backdrop: image)),
    );
    expect(find.byType(FrostAmbientBackdrop), findsOneWidget);
    expect(tester.getTopLeft(find.text('primary')).dy, 24);
    expect(tester.getTopLeft(find.text('technical')).dy - tester.getBottomLeft(find.text('primary')).dy, 24);
    await tester.pumpWidget(app(const FrostDetailLayout(stage: SizedBox(), primary: Text('primary'))));
    expect(find.byType(FrostAmbientBackdrop), findsNothing);
    final context = tester.element(find.byType(FrostDetailLayout));
    expect(
      tester.widget<ColoredBox>(find.descendant(of: find.byType(FrostDetailLayout), matching: find.byType(ColoredBox)).first).color,
      FrostThemeTokens.of(context).surface,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('160-wide module at scale 2 wraps header and title2 value, constrains graphic', (tester) async {
    await display(
      tester,
      FrostModule(
        title: 'Complete module heading',
        value: '123456789',
        note: 'Complete explanatory note',
        graphic: FrostMeter(value: .5, semanticLabel: 'meter'),
      ),
      width: 160,
      scale: 2,
    );
    expect(tester.getSize(find.byType(FrostModule)).width, 160);
    final paragraph = tester.renderObject<RenderParagraph>(find.text('123456789'));
    expect(paragraph.maxLines, isNull);
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(paragraph.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 9)).length, greaterThan(1));
    expect(find.descendant(of: find.byType(FrostModule), matching: find.byType(SingleChildScrollView)), findsNothing);
    expect(tester.getSize(find.byType(FrostMeter)).width, 128);
    expect(tester.takeException(), isNull);
  });
}

class _Counter extends StatefulWidget {
  const _Counter({required this.id});
  final String id;
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;
  @override
  Widget build(BuildContext context) => TextButton(onPressed: () => setState(() => count++), child: Text('${widget.id} $count'));
}

// A decoded one-pixel image keeps backdrop tests independent of network or assets.
final kTransparentImage = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  11,
  73,
  68,
  65,
  84,
  120,
  156,
  99,
  96,
  0,
  2,
  0,
  0,
  5,
  0,
  1,
  165,
  246,
  69,
  64,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];
