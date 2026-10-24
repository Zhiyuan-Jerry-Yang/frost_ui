import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

class FakeWindow extends ChangeNotifier implements FrostWindowActions {
  FrostCaptionState current = const FrostCaptionState(maximized: false, active: true, maximizeHovered: false, maximizePressed: false, failed: false);
  final calls = <List<FrostHitRegion>>[];
  final operations = <String>[];
  @override
  FrostCaptionState get captionState => current;
  void change({bool maximized = false, bool active = true, bool hovered = false, bool pressed = false, bool failed = false}) {
    current = FrostCaptionState(maximized: maximized, active: active, maximizeHovered: hovered, maximizePressed: pressed, failed: failed);
    notifyListeners();
  }

  @override
  void updateHitRegions(List<FrostHitRegion> regions) => calls.add(List.of(regions));
  @override
  Future<void> minimize() async => operations.add('minimize');
  @override
  Future<void> toggleMaximized() async => operations.add('maximize');
  @override
  Future<void> close() async => operations.add('close');
  @override
  Future<void> retry() async => operations.add('retry');
}

Widget host(FakeWindow? window, Widget child) => frostTestApp(FrostWindowCaptionScope(window: window, child: child));
Widget region({double width = 100, double height = 40, FrostHitKind kind = FrostHitKind.caption}) => FrostCaptionRegion(
  kind: kind,
  child: SizedBox(width: width, height: height),
);
Finder button(String label) => find.ancestor(of: find.bySemanticsLabel(label), matching: find.byType(IconButton));
Color materialColor(WidgetTester tester, Finder root) => tester.widget<Material>(find.descendant(of: root, matching: find.byType(Material)).first).color!;
Widget buttons() => const Align(
  alignment: Alignment.topRight,
  child: SizedBox(height: 40, child: FrostCaptionButtons()),
);

void main() {
  testWidgets('Linux host appearance overrides Theme.platform and follows live button lists', (tester) async {
    final window = FakeWindow();
    FrostCaptionState state(FrostCaptionStyle style, List<FrostCaptionAction> left, List<FrostCaptionAction> right) => FrostCaptionState(
      maximized: false,
      active: true,
      maximizeHovered: false,
      maximizePressed: false,
      failed: false,
      style: style,
      leftButtons: left,
      rightButtons: right,
    );
    window.current = state(FrostCaptionStyle.adwaita, [], [FrostCaptionAction.close]);
    await tester.pumpWidget(
      host(
        window,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 500,
            height: 40,
            child: Row(
              children: [
                FrostCaptionButtons(side: FrostCaptionSide.left),
                Spacer(),
                FrostCaptionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(IconButton), findsOneWidget);
    final close = find.byWidgetPredicate((widget) => widget is IconButton && widget.tooltip == 'L.close');
    expect(tester.getSize(close).width, FrostCaptionMetrics.linuxButtonSize);
    expect(tester.widget<IconButton>(close).style!.shape!.resolve({}), isA<CircleBorder>());
    await tester.tap(close);
    expect(window.operations, ['close']);
    window.current = state(FrostCaptionStyle.breeze, [FrostCaptionAction.close], [FrostCaptionAction.minimize, FrostCaptionAction.maximize]);
    window.notifyListeners();
    await tester.pump();
    expect(find.byType(IconButton), findsNWidgets(3));
    expect(tester.getCenter(close).dx, lessThan(tester.getCenter(find.byTooltip('L.minimize')).dx));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(close));
    await tester.pumpAndSettle();
    expect(materialColor(tester, close), FrostCaptionColors.closeHover);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('system decoration mode never draws a duplicate client button row', (tester) async {
    final window = FakeWindow();
    window.current = const FrostCaptionState(
      maximized: false,
      active: true,
      maximizeHovered: false,
      maximizePressed: false,
      failed: false,
      mode: FrostCaptionMode.system,
    );
    await tester.pumpWidget(host(window, buttons()));
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('native control geometry reserves one top row and never duplicates native buttons', (tester) async {
    final window = FakeWindow();
    window.current = const FrostCaptionState(
      maximized: false,
      active: true,
      maximizeHovered: false,
      maximizePressed: false,
      failed: false,
      mode: FrostCaptionMode.nativeControls,
      leftButtons: [],
      rightButtons: [],
      nativeControls: Rect.fromLTRB(12, 12, 72, 32),
    );
    const target = SizedBox(key: ValueKey('native-safe-content'), width: 100, height: 40);
    await tester.pumpWidget(
      host(
        window,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 500,
            height: 40,
            child: FrostNativeCaptionPadding(child: FrostNativeCaptionPadding(child: target)),
          ),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const ValueKey('native-safe-content'))).dx, 80);
    await tester.pumpWidget(
      host(
        window,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(height: 40, child: FrostCaptionButtons()),
        ),
      ),
    );
    expect(find.byType(IconButton), findsNothing);
    window.current = const FrostCaptionState(
      maximized: false,
      active: true,
      maximizeHovered: false,
      maximizePressed: false,
      failed: false,
      mode: FrostCaptionMode.nativeControls,
      leftButtons: [],
      rightButtons: [],
    );
    window.notifyListeners();
    await tester.pumpWidget(
      host(
        window,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: 500, height: 40, child: FrostNativeCaptionPadding(child: target)),
        ),
      ),
    );
    expect(tester.getTopLeft(find.byKey(const ValueKey('native-safe-content'))).dx, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('client decoration uses reported left/right button lists and order', (tester) async {
    final window = FakeWindow();
    window.current = const FrostCaptionState(
      maximized: false,
      active: true,
      maximizeHovered: false,
      maximizePressed: false,
      failed: false,
      leftButtons: [FrostCaptionAction.close],
      rightButtons: [FrostCaptionAction.minimize, FrostCaptionAction.maximize],
    );
    await tester.pumpWidget(
      host(
        window,
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 500,
            height: 40,
            child: Row(
              children: [
                FrostCaptionButtons(side: FrostCaptionSide.left),
                Spacer(),
                FrostCaptionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
    expect(tester.getCenter(find.byTooltip('L.close')).dx, lessThan(tester.getCenter(find.byTooltip('L.minimize')).dx));
    expect(tester.getCenter(find.byTooltip('L.minimize')).dx, lessThan(tester.getCenter(find.byTooltip('L.maximize')).dx));
    await tester.tap(find.byTooltip('L.close'));
    expect(window.operations, ['close']);
    expect(tester.takeException(), isNull);
  });

  test('hit region value equality includes rect and kind', () {
    const a = FrostHitRegion(rect: Rect.fromLTWH(10, 20, 30, 40), kind: FrostHitKind.caption);
    const b = FrostHitRegion(rect: Rect.fromLTWH(10, 20, 30, 40), kind: FrostHitKind.caption);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(const FrostHitRegion(rect: Rect.fromLTWH(10, 20, 30, 40), kind: FrostHitKind.maximize)));
  });
  testWidgets('first frame reports window coordinates and batches unchanged regions', (tester) async {
    final window = FakeWindow();
    await tester.pumpWidget(
      host(
        window,
        Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 24, top: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                region(),
                region(width: 46, kind: FrostHitKind.maximize),
              ],
            ),
          ),
        ),
      ),
    );
    expect(window.calls, [
      [
        const FrostHitRegion(rect: Rect.fromLTWH(24, 16, 100, 40), kind: FrostHitKind.caption),
        const FrostHitRegion(rect: Rect.fromLTWH(124, 16, 46, 40), kind: FrostHitKind.maximize),
      ],
    ]);
    await tester.pump();
    await tester.pump();
    expect(window.calls.length, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('resize and paint-only transforms update coordinates', (tester) async {
    final window = FakeWindow();
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Widget tree(double x) => host(
      window,
      Align(
        alignment: Alignment.topRight,
        child: Transform.translate(offset: Offset(x, 0), child: region()),
      ),
    );
    await tester.pumpWidget(tree(0));
    expect(window.calls.single.single.rect, const Rect.fromLTWH(700, 0, 100, 40));
    tester.view.physicalSize = const Size(1000, 700);
    await tester.pump();
    expect(window.calls.last.single.rect, const Rect.fromLTWH(900, 0, 100, 40));
    await tester.pumpWidget(tree(-20));
    expect(window.calls.last.single.rect, const Rect.fromLTWH(880, 0, 100, 40));
  });
  testWidgets('Offstage retained Visibility zero-size and removal clear regions', (tester) async {
    final window = FakeWindow();
    final child = region();
    Widget tree(Widget child) => host(
      window,
      Align(
        alignment: Alignment.topLeft,
        child: RepaintBoundary(child: child),
      ),
    );
    await tester.pumpWidget(tree(Offstage(offstage: false, child: child)));
    expect(window.calls.last, isNotEmpty);
    await tester.pumpWidget(tree(Offstage(child: child)));
    expect(window.calls.last, isEmpty);
    await tester.pumpWidget(tree(Visibility(visible: true, maintainState: true, maintainAnimation: true, maintainSize: true, child: child)));
    expect(window.calls.last, isNotEmpty);
    await tester.pumpWidget(tree(Visibility(visible: false, maintainState: true, maintainAnimation: true, maintainSize: true, child: child)));
    expect(window.calls.last, isEmpty);
    await tester.pumpWidget(tree(region(width: 0)));
    expect(window.calls.last, isEmpty);
    await tester.pumpWidget(tree(child));
    expect(window.calls.last, isNotEmpty);
    await tester.pumpWidget(tree(const SizedBox()));
    expect(window.calls.last, isEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final foreignOwner in [false, true]) {
    testWidgets('caption sync ignores a temporarily orphaned attached region foreignOwner=$foreignOwner', (tester) async {
      final window = FakeWindow();
      await tester.pumpWidget(host(window, Align(alignment: Alignment.topLeft, child: region())));
      expect(window.calls.last, isNotEmpty);
      final box = tester.renderObject<RenderBox>(find.byType(FrostCaptionRegion));
      final parent = box.parent! as RenderPositionedBox;
      final originalOwner = box.owner!;
      final isolatedOwner = PipelineOwner();
      final isolatedRoot = RenderPositionedBox();
      if (foreignOwner) isolatedOwner.rootNode = isolatedRoot;
      parent.child = null;
      // An Overlay/global-key transfer can leave an attached node outside the
      // view's ancestor chain. Attachment alone does not imply live geometry.
      box.attach(foreignOwner ? isolatedOwner : originalOwner);
      try {
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(window.calls.last, isEmpty);
      } finally {
        box.detach();
        parent.child = box;
        isolatedOwner.rootNode = null;
        isolatedRoot.dispose();
        isolatedOwner.dispose();
      }
      await tester.pump();
      expect(window.calls.last.single.rect, const Rect.fromLTWH(0, 0, 100, 40));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('caption regions clear on detach and follow a live Overlay reparent', (tester) async {
    final window = FakeWindow();
    final key = GlobalKey();
    final target = FrostCaptionRegion(key: key, kind: FrostHitKind.caption, child: const SizedBox(width: 100, height: 40));
    late StateSetter move;
    var floating = false;
    await tester.pumpWidget(
      host(
        window,
        StatefulBuilder(
          builder: (context, setState) {
            move = setState;
            return Overlay.wrap(
              child: Stack(
                children: [
                  if (!floating) Positioned(left: 10, top: 20, child: target),
                  if (floating) Positioned(left: 200, top: 50, child: target),
                ],
              ),
            );
          },
        ),
      ),
    );
    expect(window.calls.last.single.rect, const Rect.fromLTWH(10, 20, 100, 40));
    move(() => floating = true);
    await tester.pump();
    expect(window.calls.last.single.rect, const Rect.fromLTWH(200, 50, 100, 40));
    await tester.pumpWidget(host(window, const SizedBox()));
    expect(window.calls.last, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('nearest collector owns regions; no-window region is transparent', (tester) async {
    final outer = FakeWindow(), inner = FakeWindow();
    await tester.pumpWidget(
      host(
        outer,
        FrostWindowCaptionScope(
          window: inner,
          child: Align(alignment: Alignment.topLeft, child: region()),
        ),
      ),
    );
    expect(outer.calls, isEmpty);
    expect(inner.calls.single.single.rect, const Rect.fromLTWH(0, 0, 100, 40));
    await tester.pumpWidget(host(null, Align(alignment: Alignment.topLeft, child: region())));
    expect(tester.getSize(find.byType(FrostCaptionRegion)), const Size(100, 40));
    expect(tester.takeException(), isNull);
  });
  for (final nestedNavigator in [false, true]) {
    testWidgets('transparent root viewer excludes covered caption regions nested=$nestedNavigator', (tester) async {
      final window = FakeWindow();
      final navigator = GlobalKey<NavigatorState>();
      late StateSetter update;
      var viewer = false;
      await tester.pumpWidget(
        host(
          window,
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              Widget shell = Align(alignment: Alignment.topLeft, child: region());
              if (nestedNavigator) {
                shell = Navigator(
                  pages: [MaterialPage<void>(child: shell)],
                  onDidRemovePage: (_) {},
                );
              }
              return Column(
                children: [
                  Align(alignment: Alignment.topLeft, child: region(width: 60, height: 20)),
                  Expanded(
                    child: Navigator(
                      key: navigator,
                      pages: [
                        MaterialPage<void>(key: const ValueKey('shell'), child: shell),
                        if (viewer)
                          const FrostDetailPage<void>(
                            key: ValueKey('viewer'),
                            opaque: false,
                            child: Align(
                              alignment: Alignment.topRight,
                              child: FrostCaptionRegion(kind: FrostHitKind.caption, child: SizedBox(width: 150, height: 40)),
                            ),
                          ),
                      ],
                      onDidRemovePage: (_) => update(() => viewer = false),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
      const shellRect = Rect.fromLTWH(0, 20, 100, 40);
      const globalRect = Rect.fromLTWH(0, 0, 60, 20);
      expect(window.calls.last.map((item) => item.rect), contains(shellRect));
      update(() => viewer = true);
      await tester.pump();
      expect(window.calls.last.map((item) => item.rect), isNot(contains(shellRect)));
      await tester.pumpAndSettle();
      expect(find.byType(FrostCaptionRegion), findsNWidgets(3));
      expect(window.calls.last.map((item) => item.rect), [globalRect, const Rect.fromLTWH(650, 20, 150, 40)]);
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(window.calls.last.map((item) => item.rect), [globalRect, shellRect]);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('buttons: absent, failed, restore, semantics, geometry and operations', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(host(null, const FrostCaptionButtons()));
      expect(find.byType(IconButton), findsNothing);
      final window = FakeWindow()..change(maximized: true, failed: true);
      await tester.pumpWidget(host(window, buttons()));
      for (final label in ['L.retry', 'L.minimize', 'L.restore', 'L.close']) {
        expect(find.bySemanticsLabel(label), findsOneWidget);
        expect(tester.getSemantics(find.bySemanticsLabel(label)).getSemanticsData().label, label);
        expect(tester.getSize(button(label)), const Size(46, 40));
        await tester.tap(button(label));
        await tester.pump();
      }
      expect(window.operations, ['retry', 'minimize', 'maximize', 'close']);
      expect(tester.widgetList<FrostCaptionGlyph>(find.byType(FrostCaptionGlyph)).map((g) => g.kind), contains(FrostCaptionGlyphKind.restore));
      expect(window.calls.first.single.kind, FrostHitKind.maximize);
      expect(window.calls.first.single.rect, tester.getRect(button('L.restore')));
      window.change();
      await tester.pump();
      expect(find.bySemanticsLabel('L.retry'), findsNothing);
      expect(find.bySemanticsLabel('L.maximize'), findsOneWidget);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('actual close hover/press and native maximize background colours', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final window = FakeWindow();
      late FrostThemeTokens tokens;
      await tester.pumpWidget(
        host(
          window,
          Builder(
            builder: (context) {
              tokens = FrostThemeTokens.of(context);
              return buttons();
            },
          ),
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(button('L.close')));
      await tester.pumpAndSettle();
      expect(materialColor(tester, button('L.close')), FrostCaptionColors.closeHover);
      await mouse.down(tester.getCenter(button('L.close')));
      await tester.pumpAndSettle();
      expect(materialColor(tester, button('L.close')), FrostCaptionColors.closePressed);
      await mouse.up();
      await mouse.moveTo(const Offset(10, 200));
      await tester.pumpAndSettle();
      window.change(hovered: true);
      await tester.pumpAndSettle();
      expect(materialColor(tester, button('L.maximize')), tokens.fillSubtle);
      window.change(hovered: true, pressed: true, active: false);
      await tester.pumpAndSettle();
      expect(materialColor(tester, button('L.maximize')), tokens.fillStrong);
      for (final glyph in tester.widgetList<FrostCaptionGlyph>(find.byType(FrostCaptionGlyph))) {
        expect(glyph.color.a, closeTo(.6, .005));
      }
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('Tab paints focus ring; Enter and space invoke operations', (tester) async {
    final semantics = tester.ensureSemantics();
    try {
      final window = FakeWindow();
      late FrostThemeTokens tokens;
      await tester.pumpWidget(
        host(
          window,
          Builder(
            builder: (context) {
              tokens = FrostThemeTokens.of(context);
              return buttons();
            },
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final material = tester.widget<Material>(find.descendant(of: button('L.minimize'), matching: find.byType(Material)).first);
      expect(material.shape, isA<RoundedRectangleBorder>());
      expect((material.shape! as OutlinedBorder).side.color, tokens.focus);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(window.operations, ['minimize', 'maximize']);
    } finally {
      semantics.dispose();
    }
  });
}
