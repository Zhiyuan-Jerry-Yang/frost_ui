import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

class _Target extends StatefulWidget {
  const _Target({required this.child, super.key});
  final Widget child;
  @override
  State<_Target> createState() => _TargetState();
}

class _TargetState extends State<_Target> {
  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  testWidgets('destination wrapper follows expanded rail and mobile targets without replacing activation or status', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final anchor = GlobalKey();
    final calls = <int>[];
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        frostTestApp(
          FrostShell(
            initiallyExpanded: true,
            destinations: [
              const FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home'),
              FrostNavDestination(
                icon: const FrostIconData.glyph(Icons.download),
                label: 'Downloads',
                badge: 3,
                progress: .5,
                builder: (_, child) => _Target(key: anchor, child: child),
              ),
            ],
            selectedIndex: 0,
            atDestinationRoot: true,
            canGoBack: false,
            onBack: () {},
            onDestinationSelected: calls.add,
            showsMobileNavigation: true,
            child: const FrostShellDestination(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state(find.byKey(anchor));
      for (final width in [1440.0, 720.0, 390.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpAndSettle();
        expect(find.byKey(anchor), findsOneWidget);
        expect(tester.state(find.byKey(anchor)), same(state));
        final rect = tester.getRect(find.byKey(anchor));
        expect(rect.width, greaterThan(0));
        expect(rect.height, greaterThan(0));
        if (width < 600) expect(rect.top, greaterThan(700));
        final label = tester.getSemantics(find.byKey(anchor)).getSemanticsData().label;
        expect(label, contains('Downloads'));
        expect(label, contains('3'));
        await tester.tap(find.byKey(anchor));
        await tester.pump();
        expect(calls.last, 1);
        expect(tester.takeException(), isNull);
      }
      expect(calls, [1, 1, 1, 1]);
    } finally {
      semantics.dispose();
    }
  });
  testWidgets('Inspector sheet threshold transfers at 900 and accepts runtime threshold changes', (tester) async {
    tester.view.physicalSize = const Size(720, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var threshold = FrostSizeClass.medium;
    var callbacks = 0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return FrostInspector(
              open: true,
              title: 'Info',
              sheetBelow: threshold,
              onOpenChanged: (_) => callbacks++,
              inspector: const Text('Panel'),
              child: const SizedBox(key: ValueKey('main')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FrostSectionHeader), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, 399);
    update(() => threshold = FrostSizeClass.expanded);
    await tester.pumpAndSettle();
    expect(find.byType(FrostSectionHeader), findsNothing);
    expect(find.text('Info'), findsNothing); // Sheet content owns its title.
    expect(find.text('Panel'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, 720);
    tester.view.physicalSize = const Size(1024, 900);
    await tester.pumpAndSettle();
    expect(find.byType(FrostSectionHeader), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('main'))).width, 703);
    expect(callbacks, 0);
    expect(tester.takeException(), isNull);
  });
}
