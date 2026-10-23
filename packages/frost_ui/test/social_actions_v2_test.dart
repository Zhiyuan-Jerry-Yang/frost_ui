import 'dart:math' as math;
import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

const offIcon = FrostIconData.glyph(IconData(0xe001)), onIcon = FrostIconData.glyph(IconData(0xe002));
Finder action(String label) => find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label && w.properties.toggled != null);
double pop(WidgetTester tester) => tester
    .widgetList<ScaleTransition>(
      find.descendant(of: find.byWidgetPredicate((w) => w is FrostToggleButton || w is FrostActionCount), matching: find.byType(ScaleTransition)),
    )
    .last
    .scale
    .value;
Widget view(Widget child, {bool reduced = false}) => frostTestApp(
  MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Center(child: child),
  ),
);
void main() {
  testWidgets('count naturally measures inside an unbounded vertical scroll', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        SingleChildScrollView(
          child: Column(
            children: [FrostActionCount(icon: offIcon, selectedIcon: onIcon, selected: false, count: 12, onChanged: (_) {}, label: 'Count')],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FrostActionCount)).height.isFinite, isTrue);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });
  testWidgets('toggle first peak is 1.2 and quick reversals continue current scale', (tester) async {
    var selected = false;
    StateSetter? update;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostToggleButton(
              icon: offIcon,
              selectedIcon: onIcon,
              selected: selected,
              onChanged: (value) => setState(() => selected = value),
              label: 'Like',
            );
          },
        ),
      ),
    );
    expect(pop(tester), 1);
    await tester.tap(action('Like'));
    await tester.pump();
    final spring = FrostMotion.snappy;
    final omega = math.sqrt(spring.stiffness / spring.mass), time = 1 / math.sqrt(spring.stiffness / spring.mass);
    expect(omega, greaterThan(0));
    await tester.pump(Duration(microseconds: (time * 1e6).round()));
    expect(pop(tester), closeTo(1.2, .002));
    final before = pop(tester);
    update!(() => selected = false);
    await tester.pump();
    expect(pop(tester), closeTo(before, .0001));
    await tester.pump(const Duration(milliseconds: 20));
    final midway = pop(tester);
    update!(() => selected = true);
    await tester.pump();
    expect(pop(tester), closeTo(midway, .0001));
    await tester.pumpAndSettle();
    expect(pop(tester), 1);
    update!(() => selected = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(pop(tester), 1);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('rapid confirmation retriggers never stack their scale or jump', (tester) async {
    var selected = false;
    late StateSetter update;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostToggleButton(icon: offIcon, selectedIcon: onIcon, selected: selected, onChanged: (_) {}, label: 'Rapid');
          },
        ),
      ),
    );
    for (var count = 0; count < 20; count++) {
      final before = pop(tester);
      update(() => selected = !selected);
      await tester.pump();
      expect(pop(tester), closeTo(before, .0001));
      await tester.pump(const Duration(milliseconds: 8));
      expect(pop(tester), inInclusiveRange(1, 1.201));
    }
    await tester.pumpAndSettle();
    expect(pop(tester), 1);
  });
  testWidgets('toggle shares icon button geometry, disabled opacity and toggled semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    await tester.pumpWidget(
      view(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostToggleButton(icon: offIcon, selectedIcon: onIcon, selected: true, onChanged: null, label: 'Disabled', size: FrostControlSize.compact),
            FrostButton.icon(icon: offIcon, label: 'Normal', onPressed: () => calls++, size: FrostControlSize.compact),
          ],
        ),
      ),
    );
    final a = tester.getSize(find.byType(FrostToggleButton)), b = tester.getSize(find.byType(FrostButton));
    expect(a, b);
    final node = tester.getSemantics(action('Disabled')).getSemanticsData();
    expect(node.flagsCollection.isToggled, Tristate.isTrue);
    expect(node.flagsCollection.isEnabled, Tristate.isFalse);
    final opacity = tester
        .widgetList<AnimatedOpacity>(find.descendant(of: find.byType(FrostToggleButton), matching: find.byType(AnimatedOpacity)))
        .map((w) => w.opacity);
    expect(opacity, contains(.38));
    await tester.tapAt(tester.getCenter(action('Disabled')));
    expect(calls, 0);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('count rolling, format, semantic single action and zero width spring', (tester) async {
    var count = 12, selected = false;
    StateSetter? update;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostActionCount(
              icon: offIcon,
              selectedIcon: onIcon,
              selected: selected,
              count: count,
              onChanged: (value) => setState(() => selected = value),
              label: 'Likes',
              format: (n) => '$n K',
            );
          },
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    expect(tester.getSemantics(action('Likes')).getSemanticsData().value, '12 K');
    final wide = tester.getSize(find.byType(FrostActionCount)).width;
    update!(() => count = 13);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final slides = tester.widgetList<SlideTransition>(find.descendant(of: find.byType(FrostActionCount), matching: find.byType(SlideTransition)));
    expect(slides.any((w) => w.position.value.dy > 0), isTrue);
    await tester.pumpAndSettle();
    update!(() => count = 11);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
    final reverse = tester.widgetList<SlideTransition>(find.descendant(of: find.byType(FrostActionCount), matching: find.byType(SlideTransition)));
    expect(reverse.any((w) => w.position.value.dy < 0), isTrue);
    await tester.pumpAndSettle();
    update!(() => count = 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final middle = tester.getSize(find.byType(FrostActionCount)).width;
    await tester.pumpAndSettle();
    final hidden = tester.getSize(find.byType(FrostActionCount)).width;
    expect(middle, inExclusiveRange(hidden, wide));
    expect(find.byType(FrostRollingText), findsNothing);
    expect(tester.getSemantics(action('Likes')).getSemanticsData().value, '');
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('reduced toggle only crossfades and counter responds without movement', (tester) async {
    var selected = false, count = 1;
    StateSetter? update;
    await tester.pumpWidget(
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostActionCount(
              icon: offIcon,
              selectedIcon: onIcon,
              selected: selected,
              count: count,
              onChanged: (value) => setState(() => selected = value),
              label: 'Likes',
            );
          },
        ),
        reduced: true,
      ),
    );
    update!(() {
      selected = true;
      count = 2;
    });
    await tester.pump();
    expect(pop(tester), 1);
    expect(tester.widget<FrostRollingText>(find.byType(FrostRollingText)).text, '2');
    expect(tester.takeException(), isNull);
  });
  testWidgets('overflow count remains inside circle at large text scale', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(
            child: FrostAvatarStack(
              avatars: List.filled(1003, const FrostAvatar(initials: 'A', semanticLabel: 'A')),
              semanticLabel: 'People',
            ),
          ),
        ),
      ),
    );
    final text = find.text('+1000');
    final transform = tester.widget<FittedBox>(find.ancestor(of: text, matching: find.byType(FittedBox)).first);
    expect(transform.fit, BoxFit.scaleDown);
    final circle = tester.getRect(find.ancestor(of: text, matching: find.byType(ClipOval)).first);
    final rect = tester.getRect(text);
    expect(rect.width, lessThanOrEqualTo(circle.width));
    expect(rect.height, lessThanOrEqualTo(circle.height));
    expect(tester.takeException(), isNull);
  });
  for (final direction in TextDirection.values) {
    testWidgets('avatar overlap, ring, uniform size, +N and single semantics $direction', (tester) async {
      final avatars = [for (var i = 0; i < 5; i++) FrostAvatar(key: ValueKey(i), size: FrostAvatarSize.xlarge, initials: '$i', semanticLabel: 'Avatar $i')];
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: direction,
            child: Center(
              child: FrostAvatarStack(avatars: avatars, label: 'People', semanticLabel: 'Five people'),
            ),
          ),
        ),
      );
      expect(find.byType(FrostAvatar), findsNWidgets(3));
      expect(find.text('+2'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey(0))), const Size(24, 24));
      final first = tester.getTopLeft(find.byKey(const ValueKey(0))).dx, second = tester.getTopLeft(find.byKey(const ValueKey(1))).dx;
      expect(second - first, direction == TextDirection.ltr ? 18 : -18);
      final rings = tester
          .widgetList<DecoratedBox>(find.descendant(of: find.byType(FrostAvatarStack), matching: find.byType(DecoratedBox)))
          .map((w) => w.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.border is Border && (d.border! as Border).top.strokeAlign == BorderSide.strokeAlignOutside);
      expect(rings.length, 4);
      expect((rings.first.border! as Border).top.width, 2);
      final semantics = tester.ensureSemantics();
      expect(tester.getSemantics(find.byType(FrostAvatarStack)).getSemanticsData().label, 'Five people People +2');
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
