import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  test('path subtitle rejects inline or status presentation', () {
    expect(() => FrostListRow(title: 'x', subtitle: 'path', subtitleKind: FrostRowSubtitleKind.path, inlineSubtitle: true), throwsAssertionError);
    expect(
      () => FrostListRow(title: 'x', subtitle: 'path', subtitleKind: FrostRowSubtitleKind.path, subtitleStatus: FrostStatusTone.positive),
      throwsAssertionError,
    );
  });
  final paths = [
    r'D:\Pictures\BooruFlow\danbooru\1270191.png',
    '/Pictures/BooruFlow/yande/363100 (1).png',
    '~/Pictures/BooruFlow/image.png',
    r'\\server\share\Pictures\image.png',
    '/Pictures/${'LongDirectory' * 12}/image.png',
    '/Pictures/${'LongFile👨‍👩‍👧‍👦' * 12}.png',
  ];
  for (final width in [120.0, 220.0, 400.0]) {
    for (final (index, path) in paths.indexed) {
      testWidgets('path $index greedily wraps and preserves copy at $width', (tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            frostTestApp(
              Center(
                child: SizedBox(width: width, child: FrostPathText(path, selectable: true)),
              ),
            ),
          );
          final host = tester.renderObject<RenderProxyBox>(
            find.byWidgetPredicate((w) => w is LeafRenderObjectWidget && w.runtimeType.toString() == '_PathParagraph'),
          );
          final paragraph = host.child! as RenderParagraph;
          expect(paragraph.text.toPlainText(includeSemanticsLabels: true), path);
          final lines = paragraph.text.toPlainText(includeSemanticsLabels: false).split('\n');
          expect(lines.join(), path);
          final root = [r'D:\Pictures\', '/Pictures/', '~/Pictures/', r'\\server\share\Pictures\'].elementAtOrNull(index);
          final rootPainter = TextPainter(
            text: TextSpan(text: root ?? '', style: paragraph.text.style),
            textDirection: TextDirection.ltr,
            textScaler: paragraph.textScaler,
          )..layout();
          final fragmentWidths = RegExp(r'[^\\/]+').allMatches(path).map((match) {
            final p = TextPainter(
              text: TextSpan(text: '${match[0]}\\', style: paragraph.text.style),
              textDirection: TextDirection.ltr,
              textScaler: paragraph.textScaler,
            )..layout();
            final value = p.width;
            p.dispose();
            return value;
          });
          final rootFits = rootPainter.width <= width && fragmentWidths.every((w) => w <= width);
          rootPainter.dispose();
          if (index < 4 && rootFits) {
            for (final line in lines.take(lines.length - 1)) {
              expect(RegExp(r'[\\/]$').hasMatch(line), isTrue, reason: lines.toString());
            }
            expect(lines.first, isNot(anyOf('D:', r'D:\', '/', '~/')));
          }
          for (final line in lines) {
            final painter = TextPainter(
              text: TextSpan(text: line, style: paragraph.text.style),
              textDirection: TextDirection.ltr,
              textScaler: paragraph.textScaler,
            )..layout();
            expect(painter.width, lessThanOrEqualTo(width + .01));
            painter.dispose();
            if (index >= 4) expect(line.characters.length, greaterThan(2));
          }
          final container = tester
              .widgetList<SelectionContainer>(find.byType(SelectionContainer))
              .firstWhere((w) => w.delegate.runtimeType.toString() == 'FrostPathSelection');
          container.delegate!.dispatchSelectionEvent(const SelectAllSelectionEvent());
          expect(container.delegate!.getSelectedContent()!.plainText, path);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
        } finally {
          semantics.dispose();
        }
      });
    }
  }
  testWidgets('path values and subtitles measure on the first frame in RTL and with large text', (tester) async {
    for (final direction in TextDirection.values) {
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: direction,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Center(
                child: SizedBox(
                  width: 300,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      FrostKeyValueList(
                        entries: [FrostKeyValue.path(label: 'Path', value: r'D:\Pictures\BooruFlow\image.png')],
                      ),
                      FrostListRow(title: 'Destination', subtitle: r'D:\Pictures\BooruFlow\image.png', subtitleKind: FrostRowSubtitleKind.path),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byType(FrostPathText), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    }
  });
}
