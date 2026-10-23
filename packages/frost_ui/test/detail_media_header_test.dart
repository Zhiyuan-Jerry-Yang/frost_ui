import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('media header occupies frame one and switches without moving content', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 47);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      frostTestApp(
        FrostMediaSystemChromeHost(
          child: FrostDetailLayout(
            header: const SizedBox(height: 48, child: Text('Wide header')),
            mediaHeader: (_, scrolled) => scrolled
                ? const SizedBox(height: 48, child: Text('Ordinary header'))
                : Row(
                    children: [
                      FrostButton.icon(label: 'Back', icon: testIcons.back, onPressed: () {}),
                      const Spacer(),
                      FrostButton.icon(label: 'More', icon: testIcons.more, onPressed: () {}),
                    ],
                  ),
            stage: Builder(
              builder: (context) {
                expect(FrostMediaStage.radiusOf(context), 0);
                return const SizedBox(key: ValueKey('media'), height: 500);
              },
            ),
            primary: const SizedBox(key: ValueKey('information'), height: 100),
            sections: const [SizedBox(height: 1500)],
          ),
        ),
      ),
    );
    final stage = tester.getRect(find.byKey(const ValueKey('media')));
    final information = tester.getRect(find.byKey(const ValueKey('information')));
    expect(stage.top, 0);
    expect(information.top, 524);
    expect(find.bySemanticsLabel('Back').hitTestable(), findsOneWidget);
    expect(find.bySemanticsLabel('More').hitTestable(), findsOneWidget);
    expect(tester.getCenter(find.bySemanticsLabel('Back')).dy, greaterThan(47));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getRect(find.byKey(const ValueKey('media'))), stage);
      expect(tester.getRect(find.byKey(const ValueKey('information'))), information);
    }
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).last);
    scroll.position.jumpTo(520);
    await tester.pump();
    expect(find.text('Ordinary header').hitTestable(), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const ValueKey('information'))).dy, information.top - 520);
    expect(tester.getTopLeft(find.byKey(const ValueKey('media'), skipOffstage: false)).dy, -520);
    scroll.position.jumpTo(0);
    await tester.pump();
    expect(find.bySemanticsLabel('Back').hitTestable(), findsOneWidget);
    expect(tester.getRect(find.byKey(const ValueKey('information'))), information);
    expect(find.byType(FrostPinnedChrome), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('both header States and the stage survive local width changes', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var width = 390.0;
    late StateSetter update;
    final normal = GlobalKey(), media = GlobalKey(), stage = GlobalKey();
    final radii = <double>[];
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                height: 800,
                child: FrostDetailLayout(
                  headerPlacement: FrostDetailHeaderPlacement.page,
                  header: _Retained(key: normal),
                  mediaHeader: (_, _) => _Retained(key: media),
                  stage: Builder(
                    builder: (context) {
                      radii.add(FrostMediaStage.radiusOf(context));
                      return _Retained(key: stage);
                    },
                  ),
                  primary: const SizedBox(height: 500),
                ),
              ),
            );
          },
        ),
      ),
    );
    final states = [normal.currentState, media.currentState, stage.currentState];
    expect(radii.last, 0);
    for (final next in [1200.0, 390.0, 1200.0, 390.0]) {
      update(() => width = next);
      await tester.pumpAndSettle();
      expect([normal.currentState, media.currentState, stage.currentState], states);
      expect(radii.last, next < 600 ? 0 : FrostRadius.lg);
      expect(find.byType(FrostPinnedChrome), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}

class _Retained extends StatefulWidget {
  const _Retained({super.key});
  @override
  State<_Retained> createState() => _RetainedState();
}

class _RetainedState extends State<_Retained> {
  @override
  Widget build(BuildContext context) => const SizedBox(height: 48);
}
