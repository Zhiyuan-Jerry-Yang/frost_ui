import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

class _NavTarget extends StatefulWidget {
  const _NavTarget({required this.child, super.key});
  final Widget child;
  @override
  State<_NavTarget> createState() => _NavTargetState();
}

class _NavTargetState extends State<_NavTarget> {
  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  testWidgets('destination bar stays with the retained root while secondary routes cover its full viewport', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var selected = 0, pushes = 0;
    var detail = false;
    late StateSetter update;
    final navigator = GlobalKey<NavigatorState>();
    final target = GlobalKey<_NavTargetState>();
    const body = ValueKey('root body'), page = ValueKey('secondary page');
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: const EdgeInsets.only(bottom: 24)),
            child: StatefulBuilder(
              builder: (context, set) {
                update = set;
                return FrostShell(
                  destinations: [
                    FrostNavDestination(
                      icon: testIcons.image,
                      label: 'Home',
                      builder: (_, child) => _NavTarget(key: target, child: child),
                    ),
                    FrostNavDestination(icon: testIcons.search, label: 'Search'),
                  ],
                  selectedIndex: selected,
                  atDestinationRoot: !detail,
                  onDestinationSelected: (index) => update(() => selected = index),
                  canGoBack: detail,
                  onBack: () => navigator.currentState!.pop(),
                  showsMobileNavigation: true,
                  child: Navigator(
                    key: navigator,
                    onDidRemovePage: (_) => update(() => detail = false),
                    pages: [
                      const MaterialPage<void>(
                        child: FrostShellDestination(child: SizedBox.expand(key: body)),
                      ),
                      if (detail)
                        FrostDetailPage<void>(
                          key: ValueKey(++pushes),
                          child: const ColoredBox(key: page, color: Colors.red),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    final originalBody = tester.getRect(find.byKey(body));
    final originalBar = tester.getRect(find.byKey(target));
    final targetState = target.currentState;
    expect(originalBody.bottom, originalBar.top);
    expect(originalBar.bottom, 776);
    update(() => selected = 1);
    await tester.pumpAndSettle();
    expect(target.currentState, same(targetState));
    expect(tester.getRect(find.byKey(target)), originalBar);
    update(() => detail = true);
    await tester.pump();
    for (var frame = 0; frame < 32; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getSize(find.byKey(page)), const Size(400, 800));
      expect(target.currentState, same(targetState));
      expect(tester.getRect(find.byKey(body, skipOffstage: false)), originalBody);
    }
    final route = ModalRoute.of(tester.element(find.byKey(page)))!;
    expect(route.popGestureEnabled, isTrue);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(target)), originalBar);
    expect(tester.getRect(find.byKey(body)), originalBody);
    expect(target.currentState, same(targetState));
    tester.view.physicalSize = const Size(1000, 800);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(body)).height, 784);
    expect(tester.takeException(), isNull);
  });
}
