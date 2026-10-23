import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  testWidgets('reader public contract needs only widgets and frost_ui', (tester) async {
    const initial = FrostReaderSettings();
    final settings = initial.copyWith(textSizeStep: 1, lineSpacingStep: 2);
    final reader = FrostReaderLayout(
      header: (context, settingsButton) => Row(children: [const Text('Title'), settingsButton]),
      slivers: const [SliverToBoxAdapter(child: FrostRichText(text: 'Body'))],
      settings: settings,
      onSettingsChanged: (_) {},
      controller: ScrollController(),
    );
    expect(reader.settings.textSizeStep, 1);
    expect(reader.settings.lineSpacingStep, 2);
    reader.controller!.dispose();
  });
}
