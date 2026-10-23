import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

class _PaintProbe extends CustomPainter {
  _PaintProbe(Listenable repaint) : super(repaint: repaint);
  int frames = 0;
  @override
  void paint(Canvas canvas, Size size) {
    frames++;
  }

  @override
  bool shouldRepaint(_PaintProbe oldDelegate) => false;
}

void main() {
  for (final opaque in [true, false]) {
    testWidgets('detail opacity=$opaque controls underlay painting and preserves route identity', (tester) async {
      final redraw = ChangeNotifier();
      addTearDown(redraw.dispose);
      final probe = _PaintProbe(redraw);
      final navigator = GlobalKey<NavigatorState>();
      late StateSetter update;
      late BuildContext viewerContext;
      var viewer = false;
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Navigator(
                key: navigator,
                pages: [
                  FrostDetailPage<void>(
                    key: const ValueKey('base'),
                    child: CustomPaint(painter: probe, child: const SizedBox.expand()),
                  ),
                  if (viewer)
                    FrostDetailPage<void>(
                      key: const ValueKey('viewer'),
                      opaque: opaque,
                      child: Builder(
                        builder: (context) {
                          viewerContext = context;
                          return const Align(alignment: Alignment.center, child: SizedBox(width: 80, height: 80));
                        },
                      ),
                    ),
                ],
                onDidRemovePage: (_) => update(() => viewer = false),
              );
            },
          ),
        ),
      );
      update(() => viewer = true);
      await tester.pumpAndSettle();
      expect(ModalRoute.of(viewerContext)!.opaque, opaque);
      expect(ModalRoute.of(viewerContext)!.settings, isA<FrostDetailPage<void>>());
      final frames = probe.frames;
      redraw.notifyListeners();
      await tester.pump();
      expect(probe.frames, opaque ? frames : greaterThan(frames));
      navigator.currentState!.pop();
      await tester.pumpAndSettle();
      redraw.notifyListeners();
      await tester.pump();
      expect(probe.frames, greaterThan(frames));
      expect(tester.takeException(), isNull);
    });
  }
}
