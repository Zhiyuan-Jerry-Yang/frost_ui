import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/display/_rich_text_parser.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/primitives/_measured_keyline.dart';

import 'r2_material_reveal_test.dart' show expectSafeLayers;
import 'support.dart';

const icon = FrostIconData.glyph(IconData(0xe020));
void main() {
  testWidgets('URL full-width period ends URL before prose and mention, including actual ink', (tester) async {
    const source = 'https://example.test/path(a)。联系 @创作者';
    final parsed = FrostRichDocument(source).nodes;
    expect(parsed.map((n) => (n.text, n.target)), [('https://example.test/path(a)', FrostRichTarget.link), ('。联系 ', null), ('@创作者', FrostRichTarget.mention)]);
    final links = <Uri>[], mentions = <String>[];
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            tokens = FrostThemeTokens.of(context);
            return FrostRichText(text: source, onLink: links.add, onMention: mentions.add);
          },
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: find.byType(FrostRichText), matching: find.byType(RichText)).first);
    final plain = (paragraph.text as TextSpan).children!.whereType<TextSpan>().single;
    expect(plain.text, '。联系 ');
    expect(plain.style!.color, tokens.textPrimary);
    expect(
      tester
          .renderObject<RenderParagraph>(find.descendant(of: find.text('https://example.test/path(a)'), matching: find.byType(RichText)).first)
          .text
          .style!
          .color,
      tokens.accentInk,
    );
    await tester.tap(find.text('https://example.test/path(a)'));
    await tester.tap(find.text('@创作者'));
    expect(links.single.toString(), 'https://example.test/path(a)');
    expect(mentions, ['创作者']);
  });
  for (final rtl in [false, true]) {
    testWidgets('mixed list reserves common icon column, divider anchors and stays lazy rtl=$rtl', (tester) async {
      var builds = 0;
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: FrostContentColumn(
              child: SizedBox(
                height: 160,
                child: FrostList<int>(
                  items: List.generate(900, (i) => i),
                  dividers: true,
                  reserveIconColumn: true,
                  itemBuilder: (_, item, highlighted) {
                    builds++;
                    return FrostListRow(title: 'Row $item', icon: item == 0 ? icon : null);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final first = tester.getRect(find.text('Row 0')), second = tester.getRect(find.text('Row 1'));
      expect(rtl ? first.right : first.left, rtl ? second.right : second.left);
      final target = FrostMeasuredKeyline.of(tester.element(find.byType(FrostDivider).first))!.currentContext!.findRenderObject() as RenderBox;
      final rect = target.localToGlobal(Offset.zero) & target.size;
      expect(rtl ? rect.right : rect.left, closeTo(rtl ? first.right : first.left, .01));
      expect(builds, lessThan(30));
      expect(tester.takeException(), isNull);
    });
    testWidgets('menu icon reservation crosses groups in same panel rtl=$rtl', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: Center(
              child: FrostMenuAnchor(
                entries: [
                  FrostMenuSection(
                    header: 'First group',
                    entries: [FrostMenuAction('With icon', icon: icon, checked: false, onSelected: () {})],
                  ),
                  const FrostMenuDivider(),
                  FrostMenuSection(
                    header: 'Second group',
                    entries: [FrostMenuAction('Without icon', checked: true, onSelected: () {})],
                  ),
                ],
                builder: (_, focus, toggle) => FrostButton(label: 'Open', onPressed: toggle),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final a = tester.getRect(find.text('With icon')), b = tester.getRect(find.text('Without icon'));
      expect(rtl ? a.right : a.left, rtl ? b.right : b.left);
      for (final title in ['First group', 'Second group']) {
        final header = tester.getRect(find.text(title));
        expect(rtl ? header.right : header.left, rtl ? a.right : a.left);
      }
    });
  }
  testWidgets('suggestions align across groups, remove uses close, leading search and fixed submit coexist', (tester) async {
    final controller = TextEditingController(), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    var removed = 0, submitted = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 500,
            child: FrostSearchInput<int>(
              controller: controller,
              focusNode: focus,
              placeholder: 'Search',
              leadingIcon: true,
              onSubmitted: (_) => submitted++,
              suggestions: [
                FrostSearchSuggestionGroup(
                  title: 'Recent',
                  items: [FrostSearchSuggestion(label: 'With icon', icon: icon, onSelected: () {}, onRemove: () => removed++)],
                ),
                FrostSearchSuggestionGroup(
                  title: 'Other',
                  items: [FrostSearchSuggestion(label: 'Without icon', onSelected: () {})],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('With icon')).dx, tester.getTopLeft(find.text('Without icon')).dx);
    final remove = find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.remove');
    expect(tester.widget<FrostButton>(remove).icon, testIcons.close);
    expect(tester.widget<FrostButton>(remove).icon, isNot(testIcons.remove));
    expect(find.byWidgetPredicate((w) => w is FrostIcon && w.icon == testIcons.search), findsNWidgets(2));
    await tester.tap(remove);
    expect(removed, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(submitted, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('overlay blur reveals without an opacity saveLayer', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Row(
                      children: [for (var i = 0; i < 30; i++) Expanded(child: ColoredBox(color: i.isEven ? Colors.black : Colors.white))],
                    ),
                  ),
                  const Positioned.fill(
                    child: FrostMaterialReveal(
                      opacity: .99,
                      child: FrostSurface(role: FrostSurfaceRole.overlay, child: SizedBox.expand()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final filter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
    expect(filter.blendMode, BlendMode.srcOver);
    expectSafeLayers(tester);
    final delta = await tester.runAsync(() async {
      final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(key)).toImage(pixelRatio: 1);
      final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      final difference = (data.getUint8((60 * 120 + 58) * 4) - data.getUint8((60 * 120 + 62) * 4)).abs();
      image.dispose();
      return difference;
    });
    // Adjacent black/white stripes must blur, rather than show a sharp duplicate.
    expect(delta, lessThanOrEqualTo(3));
  });
}
