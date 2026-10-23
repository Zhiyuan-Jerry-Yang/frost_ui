import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'support.dart';

void main() {
  testWidgets('stationary content fades gradually over the complete route progress', (tester) async {
    final animation = AnimationController(vsync: tester, duration: FrostMotion.page, reverseDuration: FrostMotion.exit);
    addTearDown(animation.dispose);
    const page = ValueKey('ordinary content');
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => frostPageTransition(context, animation, kAlwaysDismissedAnimation, const ColoredBox(key: page, color: Colors.red)),
        ),
      ),
    );
    double alpha() => tester.widget<FrostMaterialReveal>(find.ancestor(of: find.byKey(page), matching: find.byType(FrostMaterialReveal)).first).opacity;
    final rect = tester.getRect(find.byKey(page));
    animation.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(alpha(), closeTo(.25, .001));
    expect(tester.getRect(find.byKey(page)), rect);
    await tester.pump(const Duration(milliseconds: 100));
    expect(alpha(), inExclusiveRange(0, 1));
    expect(tester.getRect(find.byKey(page)), rect);
    await tester.pumpAndSettle();
    expect(alpha(), 1);
    animation.reverse();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(alpha(), closeTo(1 - 80 / FrostMotion.exit.inMilliseconds, .001));
    expect(tester.getRect(find.byKey(page)), rect);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
