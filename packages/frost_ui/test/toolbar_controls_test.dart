import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  Widget header() => FrostPageHeader(
    leading: [FrostTitleMenu(title: 'Anime-Pictures', entries: const [])],
    controls: [
      FrostToolbarItem.menu(
        label: 'Latest selection',
        priority: FrostToolbarPriority.normal,
        entries: [FrostMenuAction('Choose latest', onSelected: () {})],
      ),
      FrostToolbarItem.menu(
        label: 'Current week',
        priority: FrostToolbarPriority.low,
        entries: [FrostMenuAction('Choose week', onSelected: () {})],
      ),
    ],
    actions: [
      FrostToolbarItem.action(label: 'Filter', icon: testIcons.search, priority: FrostToolbarPriority.high, onPressed: () {}),
      FrostToolbarItem.action(label: 'Download batch', icon: testIcons.download, onPressed: () {}),
    ],
  );
  testWidgets('controls follow leading and share one overflow, preserving the full source', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(frostTestApp(header()));
    final source = tester.getRect(find.text('Anime-Pictures'));
    final control = tester.getRect(find.text('Latest selection').hitTestable());
    final filter = findFrostTooltip('Filter').hitTestable();
    expect(control.left, greaterThan(source.right));
    expect(control.right, lessThan(tester.getRect(filter).left));
    tester.view.physicalSize = const Size(390, 800);
    await tester.pumpAndSettle();
    final sourceText = tester.renderObject<RenderParagraph>(find.text('Anime-Pictures'));
    expect(sourceText.didExceedMaxLines, isFalse);
    expect(tester.getRect(find.text('Anime-Pictures')).right, lessThan(390));
    expect(findFrostTooltip('L.more').hitTestable(), findsOneWidget);
    expect(filter, findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final kind in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('overflow uses actual $kind at the same narrow width', (tester) async {
      tester.view.physicalSize = const Size(390, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(frostTestApp(header()));
      await tester.pumpAndSettle();
      final more = findFrostTooltip('L.more').hitTestable();
      final pointer = await tester.createGesture(kind: kind);
      await pointer.down(tester.getCenter(more));
      await pointer.up();
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.sheet),
        kind == PointerDeviceKind.touch ? findsOneWidget : findsNothing,
      );
      expect(find.text('Current week').hitTestable(), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await pointer.removePointer();
      expect(tester.takeException(), isNull);
    });
  }
}
