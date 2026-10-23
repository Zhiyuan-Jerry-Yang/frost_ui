import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

class _Source extends FrostListSource<int> {
  _Source(this.failure);
  final bool failure;
  @override
  Future<List<int>> initList() async {
    if (failure) throw 'failed';
    return [];
  }

  @override
  Future<List<int>> nextList() async => [];
}

void main() {
  for (final width in [180.0, 360.0]) {
    testWidgets('diagnostics wrap every code line and copy the unmodified text at $width', (tester) async {
      final text = 'source=gelbooru\ncode=challengeRequired\nmessage=${List.filled(100, "LongIdentifier123").join()}\n${List.filled(30, "长行诊断").join()}';
      final copied = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        copied.add(call);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: width,
              child: FrostCodeBlock(text: text, wrap: FrostCodeWrap.anywhere),
            ),
          ),
        ),
      );
      final input = tester.widget<EditableText>(find.byType(EditableText));
      expect(input.controller.text, text);
      final render = tester.state<EditableTextState>(find.byType(EditableText)).renderEditable;
      final boxes = render.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length));
      expect(boxes.length, greaterThan(20));
      for (final box in boxes) {
        expect(box.left, greaterThanOrEqualTo(-.001));
        expect(box.right, lessThanOrEqualTo(render.size.width + .001));
      }
      expect(tester.widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView)).where((s) => s.scrollDirection == Axis.horizontal), isEmpty);
      final copy = findFrostTooltip('L.copy');
      final copyRect = tester.getRect(copy), textRect = tester.getRect(find.byType(EditableText));
      expect(copyRect.left, greaterThan(textRect.right));
      expect(copyRect.top, textRect.top);
      await tester.tap(copy);
      await tester.pump();
      expect(copied.where((c) => c.method == 'Clipboard.setData').single.arguments, {'text': text});
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('ordinary code retains its default unwrapped horizontal scrolling', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(width: 180, child: FrostCodeBlock(text: List.filled(100, 'sourceCode').join())),
        ),
      ),
    );
    expect(tester.widgetList<SingleChildScrollView>(find.byType(SingleChildScrollView)).where((s) => s.scrollDirection == Axis.horizontal).length, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('paged failure defaults to loadFailed while generic errors retain error', (tester) async {
    final source = _Source(true);
    await source.refresh(true);
    await tester.pumpWidget(
      frostTestApp(
        FrostLoadingScrollView(
          slivers: [FrostSliverDataList<int>(source: source, firstLoadSkeleton: const SizedBox(), itemBuilder: (_, value, index) => Text('$value'))],
        ),
      ),
    );
    expect(find.text('L.loadFailed'), findsOneWidget);
    expect(find.text('L.error'), findsNothing);
    await tester.pumpWidget(frostTestApp(FrostErrorContent.fromError(error: 'failed', onRetry: () {})));
    expect(find.text('L.error'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    source.dispose();
  });
  for (final failure in [false, true]) {
    for (final bottom in [0.0, 24.0]) {
      testWidgets('short paged state has no range failure=$failure safeBottom=$bottom', (tester) async {
        final source = _Source(failure);
        await source.refresh(true);
        final scroll = ScrollController();
        await tester.pumpWidget(
          frostTestApp(
            Scaffold(
              body: MediaQuery(
                data: MediaQueryData(padding: EdgeInsets.only(bottom: bottom)),
                child: SafeArea(
                  child: FrostRefreshView(
                    scrollController: scroll,
                    onRefresh: source.refresh,
                    builder: (_, physics, locators) => FrostLoadingScrollView(
                      controller: scroll,
                      physics: physics,
                      slivers: [
                        const SliverToBoxAdapter(child: SizedBox(height: 52)),
                        ?locators.sliverHeader,
                        FrostSliverDataList<int>(source: source, firstLoadSkeleton: const SizedBox(), itemBuilder: (_, value, index) => Text('$value')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            platform: TargetPlatform.android,
          ),
        );
        await tester.pumpAndSettle();
        expect(scroll.position.maxScrollExtent, 0);
        for (final state in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
          if (state.position.axis == Axis.vertical) expect(state.position.maxScrollExtent, 0);
        }
        expect(find.byType(FrostLoadingMoreIndicator<int>), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        source.dispose();
        scroll.dispose();
      });
    }
  }
}
