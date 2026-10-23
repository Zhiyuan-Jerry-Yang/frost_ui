import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'support.dart';

class TestRouter extends RouterDelegate<Object> with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  TestRouter(this.child);
  final Widget child;
  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  Future<void> setNewRoutePath(Object configuration) async {}
  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: [MaterialPage<void>(child: child)],
    onDidRemovePage: (_) {},
  );
}

void main() {
  testWidgets('router builder lives inside every common wrapper and can show toast', (tester) async {
    final delegate = TestRouter(const Text('route'));
    addTearDown(delegate.dispose);
    var observed = false;
    await tester.pumpWidget(
      FrostScope(
        reduceTransparency: true,
        child: FrostApp.router(
          config: testConfig,
          title: 'Test',
          routerConfig: RouterConfig<Object>(routerDelegate: delegate),
          appearance: FrostAppearance(
            lightAccent: FrostPalettes.pink.accentPresets[1],
            darkAccent: FrostPalettes.pink.accentPresets[1],
            mode: ThemeMode.light,
            lightTone: FrostTone.warm,
          ),
          density: FrostDensity.compact,
          locale: const Locale('en', 'US'),
          builder: (context, child) {
            observed = true;
            expect(FrostThemeTokens.of(context).accent, FrostPalettes.pink.accentPresets[1]);
            expect(FrostThemeTokens.of(context).tone, FrostTone.warm);
            expect(FrostDensity.of(context).name, FrostDensity.compact.name);
            expect(FrostScope.maybeOf(context)!.reduceTransparency, true);
            expect(context.findAncestorWidgetOfExactType<FrostToastHost>(), isNotNull);
            expect(context.findAncestorWidgetOfExactType<FrostInputFeedback>(), isNotNull);
            expect(context.findAncestorWidgetOfExactType<SkeletonizerConfig>(), isNotNull);
            expect(context.findAncestorWidgetOfExactType<AnnotatedRegion<SystemUiOverlayStyle>>(), isNotNull);
            return Column(
              children: [
                TextButton(onPressed: () => FrostToast.info('from builder'), child: const Text('notify')),
                Expanded(child: child!),
              ],
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(observed, true);
    expect(find.text('route'), findsOneWidget);
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).debugShowCheckedModeBanner, false);
    await tester.tap(find.text('notify'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('from builder'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  for (final reduced in [false, true]) {
    testWidgets('theme animation and inherited motion are correct: $reduced', (tester) async {
      final delegate = TestRouter(const SizedBox());
      addTearDown(delegate.dispose);
      late bool actualMotion;
      late double scale;
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced, textScaler: const TextScaler.linear(2)),
          child: FrostApp.router(
            config: testConfig,
            title: 'Test',
            routerConfig: RouterConfig<Object>(routerDelegate: delegate),
            builder: (context, child) {
              actualMotion = MediaQuery.disableAnimationsOf(context);
              scale = MediaQuery.textScalerOf(context).scale(10);
              return child!;
            },
          ),
        ),
      );
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeAnimationDuration, reduced ? Duration.zero : FrostMotion.layoutFade);
      expect(tester.widget<AnimatedTheme>(find.byType(AnimatedTheme)).duration, app.themeAnimationDuration);
      expect(actualMotion, reduced);
      expect(scale, 20);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('appearance retains independent dark tone and accent', (tester) async {
    final delegate = TestRouter(const SizedBox());
    addTearDown(delegate.dispose);
    late FrostThemeTokens tokens;
    await tester.pumpWidget(
      FrostApp.router(
        config: testConfig,
        title: 'Test',
        routerConfig: RouterConfig<Object>(routerDelegate: delegate),
        appearance: FrostAppearance(
          mode: ThemeMode.dark,
          lightAccent: FrostPalettes.pink.accentPresets[0],
          darkAccent: FrostPalettes.pink.accentPresets[1],
          lightTone: FrostTone.cool,
          darkTone: FrostTone.warm,
        ),
        builder: (context, child) {
          tokens = FrostThemeTokens.of(context);
          return child!;
        },
      ),
    );
    expect(tokens.isDark, true);
    expect(tokens.tone, FrostTone.warm);
    expect(tokens.accent, FrostPalettes.pink.accentPresets[1]);
    expect(tester.takeException(), isNull);
  });
  testWidgets('explicit font locale is forwarded while localization delegates retain their own fallback', (tester) async {
    final delegate = TestRouter(const Text('content'));
    addTearDown(delegate.dispose);
    await tester.pumpWidget(
      FrostApp.router(
        config: testConfig,
        title: 'Test',
        locale: const Locale('zh', 'CN'),
        routerConfig: RouterConfig<Object>(routerDelegate: delegate),
        builder: (context, child) {
          expect(Theme.of(context).textTheme.bodyMedium!.fontFamily, testFonts.simplifiedChinese);
          expect(MaterialLocalizations.of(context), isA<DefaultMaterialLocalizations>());
          return child!;
        },
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
