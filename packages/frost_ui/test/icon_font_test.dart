import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  for (final rtl in [false, true]) {
    testWidgets('font icon keeps theme, semantic label and direction rtl=$rtl', (tester) async {
      const data = IconData(0xe900, fontFamily: 'AppIcons', matchTextDirection: true);
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            child: const IconTheme(
              data: IconThemeData(size: 18, color: Colors.blue),
              child: FrostIcon(FrostIconData.glyph(data), semanticLabel: 'Back'),
            ),
          ),
        ),
      );
      final icon = tester.widget<Icon>(find.byType(Icon));
      expect(icon.icon, data);
      expect(icon.size, 18);
      expect(icon.color, Colors.blue);
      expect(icon.semanticLabel, 'Back');
      final transforms = tester.widgetList<Transform>(find.descendant(of: find.byType(Icon), matching: find.byType(Transform)));
      expect(transforms.any((widget) => widget.transform.storage[0] < 0), rtl);
      expect(tester.takeException(), isNull);
    });
  }
}
