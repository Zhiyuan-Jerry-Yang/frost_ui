import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('tile and indicator interpolate rendered ink and selection fill; mount and reduced motion stay settled', (tester) async {
    for (final form in FrostNavItemForm.values) {
      for (final reduced in [false, true]) {
        var selected = false;
        late StateSetter update;
        await tester.pumpWidget(
          frostTestApp(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
                child: StatefulBuilder(
                  builder: (context, set) {
                    update = set;
                    return Center(
                      child: SizedBox(
                        width: 176,
                        child: Material(
                          type: MaterialType.transparency,
                          child: FrostNavItem(label: 'Destination', icon: testIcons.image, selected: selected, progress: 1, form: form, onTap: () {}),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            density: FrostDensity.compact,
          ),
        );
        final item = find.byType(FrostNavItem);
        final tokens = FrostThemeTokens.of(tester.element(item));
        final target = form == FrostNavItemForm.tile ? tokens.selectionInk : tokens.accent;
        final icon = find.descendant(of: item, matching: find.byType(FrostIcon));
        expect(_ink(tester, icon), tokens.textSecondary);
        expect(tester.widget<ScaleTransition>(find.descendant(of: item, matching: find.byType(ScaleTransition))).scale.value, 1);
        update(() => selected = true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 70));
        if (reduced) {
          expect(_ink(tester, icon), target);
          expect(_ink(tester, find.text('Destination')), target);
          expect(tester.widget<ScaleTransition>(find.descendant(of: item, matching: find.byType(ScaleTransition))).scale.value, 1);
        } else {
          _between(_ink(tester, icon), tokens.textSecondary, target);
          _between(_ink(tester, find.text('Destination')), tokens.textSecondary, target);
          final transform = tester.renderObject<RenderTransform>(
            find.descendant(
              of: find.descendant(of: item, matching: find.byType(ScaleTransition)),
              matching: find.byType(Transform),
            ),
          );
          expect(transform.child!.getTransformTo(transform).storage[0], 1);
          if (form == FrostNavItemForm.tile) {
            final box = tester.renderObject<RenderDecoratedBox>(
              find.descendant(of: item, matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration)).first,
            );
            expect((box.decoration as BoxDecoration).color!.a, inExclusiveRange(0, tokens.selectionFill.a));
          }
        }
        await tester.pump(const Duration(milliseconds: 400));
        expect(_ink(tester, icon), target);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('mobile navigation animates actual label/icon colors and stable graphic scale without a moving highlight', (tester) async {
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final reduced in [false, true]) {
      var selected = 0;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  return FrostShell(
                    showsMobileNavigation: true,
                    destinations: [
                      FrostNavDestination(icon: testIcons.image, label: 'First'),
                      FrostNavDestination(icon: testIcons.search, label: 'Second'),
                    ],
                    selectedIndex: selected,
                    onDestinationSelected: (v) => set(() => selected = v),
                    canGoBack: false,
                    onBack: () {},
                    atDestinationRoot: true,
                    child: const FrostShellDestination(child: SizedBox.expand()),
                  );
                },
              ),
            ),
          ),
        ),
      );
      final item = find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Second' && w.properties.selected != null);
      final icon = find.descendant(of: item, matching: find.byType(FrostIcon));
      final tokens = FrostThemeTokens.of(tester.element(item));
      expect(_ink(tester, icon), tokens.textSecondary);
      update(() => selected = 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      if (reduced) {
        expect(_ink(tester, icon), tokens.selectionInk);
      } else {
        _between(_ink(tester, icon), tokens.textSecondary, tokens.selectionInk);
        _between(_ink(tester, find.text('Second')), tokens.textSecondary, tokens.selectionInk);
        expect(tester.widget<ScaleTransition>(find.ancestor(of: icon, matching: find.byType(ScaleTransition))).scale.value, 1);
      }
      await tester.pump(const Duration(milliseconds: 400));
      expect(_ink(tester, icon), tokens.selectionInk);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
}

Color _ink(WidgetTester tester, Finder owner) {
  final paragraph = tester.renderObject<RenderParagraph>(find.descendant(of: owner, matching: find.byType(RichText)));
  return (paragraph.text as TextSpan).style!.color!;
}

void _between(Color value, Color start, Color end) {
  expect(value, isNot(start));
  expect(value, isNot(end));
  for (final (v, a, b) in [(value.r, start.r, end.r), (value.g, start.g, end.g), (value.b, start.b, end.b), (value.a, start.a, end.a)]) {
    expect(v, inInclusiveRange(a < b ? a : b, a > b ? a : b));
  }
}
