import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('nullable control defaults inherit independently and notify', (tester) async {
    late FrostControlSize size;
    late bool enabled;
    final value = ValueNotifier(false);
    addTearDown(value.dispose);
    await tester.pumpWidget(
      frostTestApp(
        ValueListenableBuilder(
          valueListenable: value,
          builder: (context, active, _) => FrostControlScope(
            size: FrostControlSize.large,
            enabled: active,
            child: FrostControlScope(
              size: FrostControlSize.compact,
              child: Builder(
                builder: (context) {
                  size = FrostControlScope.sizeOf(context);
                  enabled = FrostControlScope.enabledOf(context);
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      ),
    );
    expect(size, FrostControlSize.compact);
    expect(enabled, false);
    value.value = true;
    await tester.pump();
    expect(enabled, true);
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) {
            size = FrostControlScope.sizeOf(context);
            enabled = FrostControlScope.enabledOf(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(size, FrostControlSize.regular);
    expect(enabled, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing size breakpoints and window scopes survive a nested viewport', (tester) async {
    for (final width in [599.0, 600.0, 899.0, 900.0, 1199.0, 1200.0]) {
      late FrostSizeClass sizeClass;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(size: Size(width, 800)),
              child: FrostLayoutScope(
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(size: const Size(320, 800)),
                  child: Builder(
                    builder: (context) {
                      sizeClass = FrostSizeClass.of(context);
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        sizeClass,
        width < 600
            ? FrostSizeClass.compact
            : width < 900
            ? FrostSizeClass.medium
            : width < 1200
            ? FrostSizeClass.expanded
            : FrostSizeClass.large,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('gaps follow the window and density, typography stays platform based', (tester) async {
    for (final density in [FrostDensity.comfortable, FrostDensity.compact]) {
      for (final width in [500.0, 1000.0]) {
        late double section, panel, hit, hero;
        await tester.pumpWidget(
          frostTestApp(
            Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(size: Size(width, 800)),
                child: FrostLayoutScope(
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(size: const Size(300, 800)),
                    child: Builder(
                      builder: (context) {
                        final gap = FrostGap.of(context);
                        section = gap.section;
                        panel = gap.panelInset;
                        hit = gap.hitInset;
                        hero = FrostTypography.of(context).style(FrostTextRole.hero).fontSize!;
                        return FrostStack.vertical(
                          gap: FrostGapSize.section,
                          children: const [
                            SizedBox(key: ValueKey('a'), height: 10),
                            SizedBox(key: ValueKey('b'), height: 10),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            density: density,
          ),
        );
        await tester.pumpAndSettle();
        expect(section, width < 600 ? 24 : 32);
        expect(panel, (width < 600 ? 16 : 20) - (density == FrostDensity.compact ? 4 : 0));
        expect(hit, width < 600 ? 8 : 12);
        expect(hero, 48);
        expect(tester.getTopLeft(find.byKey(const ValueKey('b'))).dy - tester.getBottomLeft(find.byKey(const ValueKey('a'))).dy, section);
      }
    }
    expect(tester.takeException(), isNull);
  });
}
