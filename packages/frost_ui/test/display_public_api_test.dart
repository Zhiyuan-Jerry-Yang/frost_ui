import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('display APIs compile with widgets.dart and no material import', () {
    const icon = FrostIconData.glyph(IconData(0xe000));
    final widgets = <Widget>[
      const FrostCountBadge(count: 5, max: 99, tone: FrostCountBadgeTone.negative),
      const SizedBox().frostBadge(120),
      FrostFilterChip(label: 'Type', value: 'Image', onPressed: () {}, onClear: () {}),
      const FrostLabel(title: 'Title', icon: icon, style: FrostLabelStyle.titleAndIcon),
      const FrostLabeledContent(label: 'Format', value: 'PNG'),
      const FrostLabeledContent(label: 'Control', content: SizedBox()),
      const FrostKeyValueList(
        entries: [FrostKeyValue(label: 'Width', value: '3840')],
      ),
      const FrostMetaLine(items: ['Image', '2026']),
      const FrostStat(value: '128', caption: 'Saved', unit: 'items'),
      const FrostStatStrip(
        stats: [FrostStat(value: '24', caption: 'Comments')],
      ),
      FrostModule(title: 'Module', icon: icon, value: '42', graphic: const SizedBox(), content: const Text('Body'), note: 'Note', onPressed: () {}),
      const FrostModuleGrid(
        items: [FrostModuleGridItem(span: FrostModuleSpan.full, child: SizedBox())],
      ),
      const FrostMeter(value: .5, semanticLabel: 'Level'),
      const FrostRangeBar(low: .2, high: .8, semanticLabel: 'Range'),
      const FrostDisclosure(title: 'Details', child: Text('Body')),
      const FrostCodeBlock(text: 'source'),
      FrostAvatar(image: MemoryImage(Uint8List(0)), size: FrostAvatarSize.large, semanticLabel: 'Image'),
      const FrostAvatar(semanticLabel: 'Child', child: Text('App-owned')),
      const FrostStatusDot(tone: FrostStatusTone.positive, label: 'Ready'),
    ];
    expect(widgets, hasLength(19));
  });
  test('FrostCard source, export and library/catalog constructs are removed', () {
    expect(File('lib/src/controls/card.dart').existsSync(), false);
    for (final directory in [Directory('lib'), Directory('../frost_ui_catalog/lib')]) {
      if (!directory.existsSync()) continue;
      for (final file in directory.listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.dart'))) {
        expect(file.readAsStringSync(), isNot(contains('FrostCard')), reason: file.path);
      }
    }
    expect(File('lib/frost_ui.dart').readAsStringSync(), isNot(contains("controls/card.dart")));
  });
}
