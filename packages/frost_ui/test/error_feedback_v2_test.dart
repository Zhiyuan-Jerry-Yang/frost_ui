import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/empty_state.dart' show FrostStateContent;

import 'display_badges_v2_test.dart' show display;
import 'support.dart';

void main() {
  testWidgets('error page narrow header and back, wide content keeps no header', (tester) async {
    for (final width in [400.0, 1000.0]) {
      await tester.pumpWidget(
        frostTestApp(
          MediaQuery(
            data: MediaQueryData(size: Size(width, 700)),
            child: FrostErrorPage(message: 'Failure summary', onRetry: () {}),
          ),
        ),
      );
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(FrostPageHeader), width < 600 ? findsOneWidget : findsNothing);
      expect(find.byType(FrostCompactBackButton), width < 600 ? findsOneWidget : findsNothing);
      expect(find.byType(FrostStateContent), findsOneWidget);
      expect(find.text('Failure summary'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('error content keeps parameters, negative icon, readable summary and retry', (tester) async {
    var retries = 0;
    await display(
      tester,
      FrostErrorContent(
        message: 'Summary',
        retryLabel: 'Try again',
        fullUrl: 'https://example.test/path?query=full',
        details: 'technical text',
        onRetry: () => retries++,
      ),
    );
    final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostErrorContent)));
    final icon = tester.widget<FrostIcon>(find.byType(FrostIcon).first);
    expect(icon.size, 28);
    expect(icon.color, tokens.negativeInk);
    final empty = tester.widget<FrostStateContent>(find.byType(FrostStateContent));
    expect(empty.title, FrostScope.labelsOf(tester.element(find.byType(FrostErrorContent))).error);
    expect(empty.message, 'Summary');
    expect(tester.widget<FrostCodeBlock>(find.byType(FrostCodeBlock).first).text, 'https://example.test/path?query=full');
    await tester.tap(find.text('Try again'));
    expect(retries, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('standalone opaque error route paints canvas and back returns to caller', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => FrostButton(
            label: 'Open error',
            onPressed: () => Navigator.of(context).push<void>(
              PageRouteBuilder<void>(
                pageBuilder: (_, animation, secondary) => MediaQuery(
                  data: const MediaQueryData(size: Size(400, 700)),
                  child: FrostErrorPage(message: 'Route failure', onRetry: () {}),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open error'));
    await tester.pumpAndSettle();
    final page = find.byType(FrostErrorPage);
    final scaffold = tester.widget<Scaffold>(find.descendant(of: page, matching: find.byType(Scaffold)));
    expect(scaffold.backgroundColor, FrostThemeTokens.of(tester.element(page)).canvas);
    await tester.tap(find.byType(FrostCompactBackButton));
    await tester.pumpAndSettle();
    expect(find.byType(FrostErrorPage), findsNothing);
    expect(find.text('Open error'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final reduced in [false, true]) {
    for (final sliver in [false, true]) {
      testWidgets('expanded details keep summary anchored and scroll below it reduced=$reduced sliver=$sliver', (tester) async {
        final content = FrostErrorContent(
          message: 'Anchored summary',
          retryLabel: 'Anchored retry',
          details: List.filled(40, 'Technical detail').join('\n'),
          onRetry: () {},
        );
        await display(
          tester,
          SizedBox(
            height: 400,
            child: sliver ? CustomScrollView(slivers: [SliverFillRemaining(hasScrollBody: false, child: content)]) : content,
          ),
          reduced: reduced,
        );
        final labels = FrostScope.labelsOf(tester.element(find.byType(FrostErrorContent)));
        final summary = [find.byType(FrostIcon).first, find.text(labels.error), find.text('Anchored summary'), find.text('Anchored retry')];
        final positions = summary.map(tester.getRect).toList();
        final disclosure = find.byType(FrostDisclosure);
        final collapsedHeight = tester.getSize(disclosure).height;
        await tester.tap(find.text(labels.errorDetails));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        for (var index = 0; index < summary.length; index++) {
          expect(tester.getRect(summary[index]), positions[index]);
        }
        final middleHeight = tester.getSize(disclosure).height;
        await tester.pumpAndSettle();
        for (var index = 0; index < summary.length; index++) {
          expect(tester.getRect(summary[index]), positions[index]);
        }
        final expandedHeight = tester.getSize(disclosure).height;
        expect(expandedHeight, greaterThan(collapsedHeight));
        expect(middleHeight, reduced ? expandedHeight : inExclusiveRange(collapsedHeight, expandedHeight));
        // The page itself does not grow or scroll on expansion, including when
        // SliverFillRemaining requests intrinsics before the first layout.
        final empty = find.byType(FrostStateContent);
        expect(tester.getSize(empty).height, 400);
        final position = tester.state<ScrollableState>(find.descendant(of: empty, matching: find.byType(Scrollable)).first).position;
        expect(position.pixels, 0);
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.tap(find.text(labels.errorDetails));
        await tester.pump(const Duration(milliseconds: 40));
        for (var index = 0; index < summary.length; index++) {
          expect(tester.getRect(summary[index]), positions[index]);
        }
        await tester.pumpAndSettle();
        await tester.tap(find.text(labels.errorDetails));
        await tester.pumpAndSettle();
        position.jumpTo(position.maxScrollExtent);
        await tester.pump();
        expect(tester.getRect(disclosure).bottom, closeTo(tester.getRect(empty).bottom, .001));
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('error details rotates one arrow, bounded code and copies exact data reduced=$reduced', (tester) async {
      final clipboard = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        clipboard.add(call);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      const details = 'line 1\nline 2\nfull error';
      await display(tester, const FrostErrorDetails(details: details), reduced: reduced);
      final labels = FrostScope.labelsOf(tester.element(find.byType(FrostErrorDetails)));
      final arrow = tester.widget<FrostIcon>(find.descendant(of: find.byType(FrostDisclosure), matching: find.byType(FrostIcon)).first).icon;
      await tester.tap(find.text(labels.errorDetails));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final rotation = tester.widget<RotationTransition>(find.byType(RotationTransition)).turns.value;
      expect(rotation, reduced ? .25 : inExclusiveRange(0, .25));
      expect(tester.widget<FrostIcon>(find.descendant(of: find.byType(FrostDisclosure), matching: find.byType(FrostIcon)).first).icon, arrow);
      await tester.pumpAndSettle();
      await tester.tap(findFrostTooltip(labels.copy));
      await tester.pump();
      expect(clipboard.where((call) => call.method == 'Clipboard.setData').single.arguments, {'text': details});
      await tester.pump(const Duration(milliseconds: 1501));
      expect(tester.takeException(), isNull);
    });
  }
  for (final error in [false, true]) {
    testWidgets('empty/error content supports SliverFillRemaining intrinsic layout error=$error', (tester) async {
      await display(
        tester,
        SizedBox(
          height: 500,
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: error
                    ? FrostErrorContent(message: 'Failed', details: 'technical', onRetry: () {})
                    : const FrostEmptyState(title: 'Empty', message: 'No items'),
              ),
            ],
          ),
        ),
      );
      expect(find.byType(FrostStateContent), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('compact message roles and plain compact action', (tester) async {
    var calls = 0;
    await display(tester, FrostCompactMessage(icon: testIcons.info, message: 'Complete summary', actionLabel: 'Action', onAction: () => calls++), scale: 2);
    final paragraph = tester.renderObject<RenderParagraph>(find.text('Complete summary'));
    expect(paragraph.text.style!.fontSize, FrostTypography.of(tester.element(find.text('Complete summary'))).style(FrostTextRole.footnote).fontSize);
    final button = tester.widget<FrostButton>(find.byType(FrostButton));
    expect(button.variant, FrostButtonVariant.plain);
    expect(button.size, FrostControlSize.compact);
    await tester.tap(find.text('Action'));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('refresh error retry is standard compact and exhausted tail remains', (tester) async {
    final source = _Source()..fails = true;
    addTearDown(source.dispose);
    await source.refresh(true);
    await display(tester, FrostLoadingMoreIndicator<int>(source: source));
    final retry = tester.widget<FrostButton>(find.byType(FrostButton));
    expect(retry.variant, FrostButtonVariant.standard);
    expect(retry.size, FrostControlSize.compact);
    source.fails = false;
    await source.refresh(true);
    await tester.pump();
    expect(find.text(FrostScope.labelsOf(tester.element(find.byType(FrostLoadingMoreIndicator<int>))).noMoreItems), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  test('feedback audit removes Material appearance calls and old empty API', () {
    final prohibited = RegExp(
      r'\b(?:TextButton|FilledButton|ElevatedButton|OutlinedButton|IconButton|AppBar)\s*(?:\.|\()|\b(?:textTheme|colorScheme)\b|\bFrostEmptyContent\b',
    );
    for (final file in Directory('lib/src/feedback').listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      expect(file.readAsStringSync(), isNot(matches(prohibited)), reason: file.path);
    }
  });
}

class _Source extends FrostListSource<int> {
  bool fails = false;
  @override
  Future<List<int>> initList() async {
    if (fails) throw StateError('failure');
    return [];
  }

  @override
  Future<List<int>> nextList() async => [];
}
