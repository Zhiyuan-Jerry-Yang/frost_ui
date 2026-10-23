import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

enum _Panel { menu, popover, hoverPreview }

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    for (final panel in _Panel.values) {
      testWidgets('$panel owns its scrolling inside RefreshView on $platform', (tester) async {
        tester.view.physicalSize = const Size(900, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final main = ScrollController();
        final previewFocus = FocusNode();
        try {
          final entries = [for (var i = 0; i < 60; i++) FrostMenuAction('Option $i', onSelected: () {})];
          Widget longContent() => Column(
            mainAxisSize: MainAxisSize.min,
            children: [for (var i = 0; i < 60; i++) SizedBox(height: 40, child: Text('Content $i'))],
          );
          final trigger = switch (panel) {
            _Panel.menu => FrostMenuAnchor(
              entries: entries,
              builder: (_, focus, toggle) => FrostButton(label: 'Open panel', onPressed: toggle),
            ),
            _Panel.popover => FrostPopover(
              title: 'Panel',
              builder: (_, focus, toggle) => FrostButton(label: 'Open panel', onPressed: toggle),
              contentBuilder: (_, close) => longContent(),
            ),
            _Panel.hoverPreview => FrostHoverPreview(
              previewBuilder: (_) => longContent(),
              child: FrostClickSurface(
                focusNode: previewFocus,
                onTap: () {},
                child: const SizedBox(width: 100, height: 40, child: Text('Open panel')),
              ),
            ),
          };
          await tester.pumpWidget(
            frostTestApp(
              FrostRefreshView(
                scrollController: main,
                onRefresh: () => true,
                builder: (context, physics, locators) => Column(
                  children: [
                    Align(alignment: Alignment.topLeft, child: trigger),
                    Expanded(
                      child: CustomScrollView(
                        controller: main,
                        physics: physics,
                        slivers: [SliverFixedExtentList(itemExtent: 40, delegate: SliverChildBuilderDelegate((_, i) => Text('Main $i'), childCount: 100))],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          main.jumpTo(180);
          await tester.pump();
          expect(main.positions, hasLength(1));
          if (panel == _Panel.hoverPreview) {
            previewFocus.requestFocus();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 600));
          } else {
            await tester.tap(find.text('Open panel'));
          }
          await tester.pumpAndSettle();
          expect(main.positions, hasLength(1), reason: 'The overlay must never attach to the page controller.');
          final pageOffset = main.offset;
          final panelState = tester
              .stateList<ScrollableState>(find.byType(Scrollable))
              .singleWhere((scrollable) => !identical(scrollable.position, main.position));
          expect(panelState.position.maxScrollExtent, greaterThan(0));
          await tester.drag(find.byWidget(panelState.widget), const Offset(0, -120));
          await tester.pumpAndSettle();
          expect(panelState.position.pixels, greaterThan(0));
          expect(main.offset, pageOffset);
          expect(main.positions, hasLength(1));
          expect(tester.takeException(), isNull);
          if (panel == _Panel.hoverPreview) {
            previewFocus.unfocus();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 150));
          } else {
            await tester.sendKeyEvent(LogicalKeyboardKey.escape);
          }
          await tester.pumpAndSettle();
          expect(main.positions, hasLength(1));
          expect(tester.stateList<ScrollableState>(find.byType(Scrollable)), hasLength(1));
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          main.dispose();
          previewFocus.dispose();
        }
      }, variant: TargetPlatformVariant.only(platform));
    }
  }
}
