import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  for (final kind in ['list', 'box', 'slivers']) {
    testWidgets('app host handles $kind with a custom non-primary controller', (tester) async {
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      final page = switch (kind) {
        'list' => ListView.builder(
          controller: scroll,
          primary: false,
          itemCount: 100,
          itemBuilder: (_, i) => SizedBox(height: 60, child: Text('Row $i')),
        ),
        'box' => SingleChildScrollView(
          controller: scroll,
          primary: false,
          child: const SizedBox(width: double.infinity, height: 6000),
        ),
        _ => CustomScrollView(
          controller: scroll,
          primary: false,
          slivers: const [SliverToBoxAdapter(child: SizedBox(height: 6000))],
        ),
      };
      await tester.pumpWidget(_app(Scaffold(body: page)));
      await tester.pumpAndSettle();
      scroll.jumpTo(1500);
      await tester.pump();
      tester.simulateStatusBarTap();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(scroll.offset, allOf(greaterThan(0), lessThan(1500)));
      await tester.pumpAndSettle();
      expect(scroll.offset, 0);
      await _unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('only the visible retained tab responds across all four destinations', (tester) async {
    final controllers = List.generate(4, (_) => ScrollController());
    addTearDown(() {
      for (final scroll in controllers) {
        scroll.dispose();
      }
    });
    var selected = 0;
    late StateSetter update;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return IndexedStack(index: selected, children: [for (final scroll in controllers) _list(scroll)]);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var index = 0; index < controllers.length; index++) {
      for (final scroll in controllers) {
        scroll.jumpTo(700);
      }
      update(() => selected = index);
      await tester.pumpAndSettle();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      for (var candidate = 0; candidate < controllers.length; candidate++) {
        expect(controllers[candidate].offset, candidate == index ? 0 : 700);
      }
    }
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final width in [390.0, 1000.0]) {
    testWidgets('post-detail layout returns its information and media to top at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          const FrostDetailLayout(
            stage: SizedBox(height: 1200, child: Text('Media')),
            primary: SizedBox(height: 2200, child: Text('Post information')),
            header: SizedBox(height: 52, child: Text('Post')),
            mediaHeader: _mediaHeader,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
      final position = scrollable.position;
      position.jumpTo(900);
      await tester.pump();
      tester.simulateStatusBarTap();
      await tester.pumpAndSettle();
      expect(position.pixels, 0);
      expect(tester.state<ScrollableState>(find.byType(Scrollable).first), same(scrollable));
      await _unmount(tester);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('root modal scrolls itself and preserves its covered nested page', (tester) async {
    final background = ScrollController(), modal = ScrollController();
    addTearDown(background.dispose);
    addTearDown(modal.dispose);
    late BuildContext nestedContext;
    await tester.pumpWidget(
      _app(
        Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              nestedContext = context;
              return _list(background);
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    background.jumpTo(700);
    unawaited(
      showModalBottomSheet<void>(
        context: nestedContext,
        useRootNavigator: true,
        builder: (_) => SizedBox(height: 300, child: _list(modal)),
      ),
    );
    await tester.pumpAndSettle();
    expect(ModalRoute.of(nestedContext)!.isCurrent, isTrue);
    modal.jumpTo(800);
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(modal.offset, 0);
    expect(background.offset, 700);
    Navigator.of(nestedContext, rootNavigator: true).pop();
    await tester.pump();
    tester.simulateStatusBarTap();
    await tester.pump(const Duration(milliseconds: 50));
    expect(background.offset, 700);
    await tester.pumpAndSettle();
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(background.offset, 0);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('a non-scrollable foreground route never falls through to the covered page', (tester) async {
    final scroll = ScrollController();
    final navigator = GlobalKey<NavigatorState>();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(_app(_list(scroll), navigator: navigator));
    await tester.pumpAndSettle();
    scroll.jumpTo(800);
    unawaited(navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Viewer')))));
    await tester.pumpAndSettle();
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(scroll.offset, 800);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('an opaque sibling Navigator blocks hit testing to the background page', (tester) async {
    final background = ScrollController(), foreground = ScrollController();
    addTearDown(background.dispose);
    addTearDown(foreground.dispose);
    await tester.pumpWidget(
      _app(
        Stack(
          fit: StackFit.expand,
          children: [
            Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => _list(background))),
            Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => Material(child: _list(foreground))),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    background.jumpTo(700);
    foreground.jumpTo(900);
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(background.offset, 700);
    expect(foreground.offset, 0);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('scrolling the page preserves text editing, keyboard and editor offset', (tester) async {
    final page = ScrollController(), editor = ScrollController();
    final input = TextEditingController(text: List.generate(60, (i) => 'Line $i').join('\n'));
    final focus = FocusNode();
    addTearDown(page.dispose);
    addTearDown(editor.dispose);
    addTearDown(input.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      _app(
        Material(
          child: Column(
            children: [
              TextField(controller: input, focusNode: focus, scrollController: editor, minLines: 3, maxLines: 3),
              Expanded(child: _list(page)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.showKeyboard(find.byType(TextField));
    await tester.pumpAndSettle();
    editor.jumpTo(editor.position.maxScrollExtent);
    page.jumpTo(900);
    await tester.pump();
    final text = input.value;
    final editorOffset = editor.offset;
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(page.offset, 0);
    expect(input.value, text);
    expect(editor.offset, editorOffset);
    expect(focus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('wide settings selects the larger content pane and leaves navigation alone', (tester) async {
    final navigation = ScrollController(), content = ScrollController();
    addTearDown(navigation.dispose);
    addTearDown(content.dispose);
    await tester.pumpWidget(
      _app(
        Row(
          children: [
            SizedBox(width: 220, child: _list(navigation)),
            Expanded(child: _list(content)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    navigation.jumpTo(700);
    content.jumpTo(800);
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(content.offset, 0);
    expect(navigation.offset, 700);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('page already at top does not reset a smaller nested vertical control', (tester) async {
    final page = ScrollController(), nested = ScrollController();
    addTearDown(page.dispose);
    addTearDown(nested.dispose);
    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          controller: page,
          child: Column(
            children: [
              SizedBox(height: 200, child: _list(nested)),
              const SizedBox(height: 1800),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    nested.jumpTo(700);
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(page.offset, 0);
    expect(nested.offset, 700);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('horizontal paging is preserved and reversed vertical pages reach visual top', (tester) async {
    final horizontal = PageController(), vertical = ScrollController();
    addTearDown(horizontal.dispose);
    addTearDown(vertical.dispose);
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            SizedBox(
              height: 100,
              child: PageView(controller: horizontal, children: const [Text('First'), Text('Second')]),
            ),
            Expanded(
              child: ListView.builder(controller: vertical, reverse: true, itemExtent: 60, itemCount: 100, itemBuilder: (_, i) => Text('Row $i')),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    horizontal.jumpToPage(1);
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(horizontal.page, 1);
    expect(vertical.offset, vertical.position.maxScrollExtent);
    await _unmount(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('reduced motion returns immediately and a disabled host suppresses legacy routing', (tester) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(_app(MediaQuery(data: const MediaQueryData(disableAnimations: true), child: _list(scroll))));
    await tester.pumpAndSettle();
    scroll.jumpTo(800);
    tester.simulateStatusBarTap();
    await tester.pump();
    expect(scroll.offset, 0);
    expect(scroll.position.isScrollingNotifier.value, isFalse);
    await tester.pumpWidget(
      _app(FrostRefreshView(scrollController: scroll, scrollToTopOnStatusBarTap: true, builder: (_, _, _) => _list(scroll)), enabled: false),
    );
    await tester.pumpAndSettle();
    scroll.jumpTo(700);
    tester.simulateStatusBarTap();
    await tester.pumpAndSettle();
    expect(scroll.offset, 700);
    await _unmount(tester);
    tester.simulateStatusBarTap();
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}

Widget _app(Widget home, {GlobalKey<NavigatorState>? navigator, bool enabled = true}) => FrostScope(
  config: testConfig,
  child: MaterialApp(
    navigatorKey: navigator,
    theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.iOS, locale: const Locale('en')),
    builder: (_, child) => FrostScrollToTopHost(
      enabled: enabled,
      child: FrostLayoutScope(child: FrostToastHost(child: child!)),
    ),
    home: home,
  ),
);

Widget _list(ScrollController controller) =>
    ListView.builder(controller: controller, primary: false, itemExtent: 60, itemCount: 100, itemBuilder: (_, i) => Text('Row $i'));

Widget _mediaHeader(BuildContext context, bool pastStage) => SizedBox(height: 52, child: Text(pastStage ? 'Post' : 'Media'));

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}
