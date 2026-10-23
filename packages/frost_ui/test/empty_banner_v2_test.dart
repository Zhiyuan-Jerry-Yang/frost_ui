import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'display_badges_v2_test.dart' show display, decorations;
import 'support.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('single-line banner centers icon text and action without excess row height $direction', (tester) async {
      await display(
        tester,
        FrostInlineBanner(tone: FrostBannerTone.info, message: 'New version', actionLabel: 'Download', onAction: () {}),
        width: 600,
        direction: direction,
      );
      final icon = find.byType(FrostIcon).first;
      final text = find.text('New version');
      final action = find.byType(FrostButton);
      expect(tester.getCenter(icon).dy, closeTo(tester.getCenter(text).dy, .001));
      expect(tester.getCenter(action).dy, closeTo(tester.getCenter(text).dy, .001));
      expect(tester.getSize(find.byType(FrostInlineBanner)).height, tester.getSize(action).height + 24);
      expect(tester.takeException(), isNull);
    });
  }

  test('empty actions allow disabled labels but reject callbacks without labels', () {
    expect(const FrostEmptyState(title: 'Empty', actionLabel: 'Create').onAction, isNull);
    expect(() => FrostEmptyState(title: 'Empty', onAction: () {}), throwsAssertionError);
    expect(const FrostInlineBanner(tone: FrostBannerTone.info, message: 'Message'), isA<Widget>());
  });
  testWidgets('empty actual geometry, type roles, max width and upper-quarter anchor', (tester) async {
    var calls = 0;
    await display(
      tester,
      SizedBox(
        height: 500,
        child: FrostEmptyState(
          icon: testIcons.empty,
          title: 'Empty title',
          message: 'Explanation',
          actionLabel: 'Create',
          onAction: () => calls++,
          details: const Text('Details'),
        ),
      ),
      width: 600,
    );
    final title = tester.renderObject<RenderParagraph>(find.text('Empty title'));
    final description = tester.renderObject<RenderParagraph>(find.text('Explanation'));
    final typography = FrostTypography.of(tester.element(find.text('Empty title')));
    final tokens = FrostThemeTokens.of(tester.element(find.text('Empty title')));
    expect(title.text.style!.fontSize, typography.style(FrostTextRole.title2).fontSize);
    expect(description.text.style!.fontSize, typography.style(FrostTextRole.callout).fontSize);
    expect(description.text.style!.color, tokens.textSecondary);
    final icon = find.byType(FrostIcon).first;
    expect(tester.getSize(icon), const Size.square(28));
    expect(tester.widget<FrostIcon>(icon).color, tokens.textTertiary);
    expect(tester.getRect(find.text('Empty title')).top - tester.getRect(icon).bottom, 12);
    expect(tester.getRect(find.text('Explanation')).top - tester.getRect(find.text('Empty title')).bottom, 8);
    expect(tester.getRect(find.byType(FrostButton)).top - tester.getRect(find.text('Explanation')).bottom, 16);
    expect(tester.getRect(find.text('Details')).top - tester.getRect(find.byType(FrostButton)).bottom, 12);
    final viewport = tester.getRect(find.byType(FrostEmptyState));
    expect(tester.getRect(icon).top, viewport.top + viewport.height / 4);
    expect(tester.getSize(find.text('Details')).width, 360);
    expect(tester.widget<FrostButton>(find.byType(FrostButton)).variant, FrostButtonVariant.standard);
    await tester.tap(find.text('Create'));
    expect(calls, 1);
  });
  testWidgets('empty starts at top and scrolls complete large content without overflow', (tester) async {
    await display(
      tester,
      SizedBox(
        height: 120,
        child: FrostEmptyState(
          icon: testIcons.empty,
          title: 'A very long complete title that keeps wrapping',
          message: 'A detailed explanation that is never truncated',
          details: const Text('Last detail'),
        ),
      ),
      width: 200,
      scale: 2,
    );
    expect(tester.getRect(find.byType(FrostIcon).first).top, tester.getRect(find.byType(FrostEmptyState)).top);
    for (final text in ['A very long complete title that keeps wrapping', 'A detailed explanation that is never truncated']) {
      expect(tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines, false);
    }
    final position = tester.state<ScrollableState>(find.descendant(of: find.byType(FrostEmptyState), matching: find.byType(Scrollable)).first).position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(tester.getRect(find.text('Last detail')).bottom, lessThanOrEqualTo(tester.getRect(find.byType(FrostEmptyState)).bottom));
    expect(tester.takeException(), isNull);
  });
  testWidgets('empty summary reanchors on viewport resize in the first layout', (tester) async {
    var height = 400.0;
    late StateSetter update;
    const content = FrostEmptyState(title: 'Resize summary', details: SizedBox(height: 200));
    await display(
      tester,
      StatefulBuilder(
        builder: (_, set) {
          update = set;
          return SizedBox(height: height, child: content);
        },
      ),
    );
    expect(tester.getRect(find.text('Resize summary')).top, tester.getRect(find.byType(FrostEmptyState)).top + height / 4);
    update(() => height = 300);
    await tester.pump();
    expect(tester.getRect(find.text('Resize summary')).top, tester.getRect(find.byType(FrostEmptyState)).top + height / 4);
    expect(tester.takeException(), isNull);
  });
  for (final tone in FrostBannerTone.values) {
    testWidgets('banner $tone actual colors, icon, roles and live region', (tester) async {
      final handle = tester.ensureSemantics();
      var actions = 0, dismisses = 0;
      await display(
        tester,
        FrostInlineBanner(tone: tone, title: 'Title', message: 'Message', actionLabel: 'Action', onAction: () => actions++, onDismiss: () => dismisses++),
        width: 600,
      );
      final tokens = FrostThemeTokens.of(tester.element(find.byType(FrostInlineBanner)));
      final (tint, ink, kind) = switch (tone) {
        FrostBannerTone.info => (tokens.infoTint, tokens.infoInk, null),
        FrostBannerTone.positive => (tokens.positiveTint, tokens.positiveInk, FrostStatusGlyphKind.success),
        FrostBannerTone.caution => (tokens.cautionTint, tokens.cautionInk, FrostStatusGlyphKind.warning),
        FrostBannerTone.negative => (tokens.negativeTint, tokens.negativeInk, FrostStatusGlyphKind.failure),
      };
      final decoration = decorations(tester, find.byType(FrostInlineBanner)).first.decoration as ShapeDecoration;
      expect(decoration.color, tint);
      expect((decoration.shape as RoundedSuperellipseBorder).borderRadius, FrostRadius.borderRadius(FrostRadius.lg));
      final glyphFinder = kind == null ? find.byType(FrostIcon).first : find.byType(FrostStatusGlyph);
      if (kind == null) {
        final widget = tester.widget<FrostIcon>(glyphFinder);
        expect(widget.icon, testIcons.info);
        expect(widget.color, ink);
        expect(widget.size, 18);
      } else {
        final widget = tester.widget<FrostStatusGlyph>(glyphFinder);
        expect(widget.kind, kind);
        expect(widget.color, ink);
        expect(widget.size, 18);
        expect(widget.animate, false);
      }
      final typography = FrostTypography.of(tester.element(find.text('Title')));
      final title = tester.renderObject<RenderParagraph>(find.text('Title'));
      expect(title.text.style!.fontWeight, FontWeight.w500);
      expect(title.text.style!.fontSize, typography.style(FrostTextRole.callout).fontSize);
      expect(tester.getRect(find.text('Message')).top - tester.getRect(find.text('Title')).bottom, 2);
      expect(tester.getRect(find.text('Title')).left - tester.getRect(glyphFinder).right, 8);
      final data = tester.getSemantics(find.byType(FrostInlineBanner)).getSemanticsData();
      expect(data.flagsCollection.isLiveRegion, tone == FrostBannerTone.caution || tone == FrostBannerTone.negative);
      final action = tester.widgetList<FrostButton>(find.byType(FrostButton)).first;
      expect(action.variant, FrostButtonVariant.plain);
      expect(action.size, FrostControlSize.compact);
      await tester.tap(find.text('Action'));
      await tester.tap(findFrostTooltip(FrostScope.labelsOf(tester.element(find.byType(FrostInlineBanner))).dismiss));
      expect(actions, 1);
      expect(dismisses, 1);
      handle.dispose();
    });
  }
  for (final direction in TextDirection.values) {
    testWidgets('banner actions reflow on first layout and dismiss stays top $direction', (tester) async {
      await display(
        tester,
        FrostInlineBanner(
          tone: FrostBannerTone.info,
          title: 'Readable title',
          message: 'Complete message wraps without truncation',
          actionLabel: 'Retry action',
          onAction: () {},
          onDismiss: () {},
        ),
        width: 220,
        scale: 2,
        direction: direction,
      );
      final action = find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Retry action');
      final close = find.byWidgetPredicate((w) => w is FrostButton && w.style != null);
      expect(tester.getRect(action).top - tester.getRect(find.text('Complete message wraps without truncation')).bottom, 8);
      expect(tester.getRect(close).top, tester.getRect(find.byType(FrostInlineBanner)).top + 12);
      expect(tester.getRect(action).left, tester.getRect(find.text('Readable title')).left);
      expect(tester.takeException(), isNull);
    });
  }
  for (final reduced in [false, true]) {
    testWidgets('banner tone color interpolates with reduced preference $reduced', (tester) async {
      var tone = FrostBannerTone.info;
      late StateSetter update;
      await display(
        tester,
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostInlineBanner(tone: tone, message: 'Message');
          },
        ),
        reduced: reduced,
      );
      Color color() => (decorations(tester, find.byType(FrostInlineBanner)).first.decoration as ShapeDecoration).color!;
      final start = color();
      final end = FrostThemeTokens.of(tester.element(find.byType(FrostInlineBanner))).negativeTint;
      update(() => tone = FrostBannerTone.negative);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      expect(color(), reduced ? end : isNot(isIn([start, end])));
      await tester.pumpAndSettle();
      expect(color(), end);
    });
  }
}
