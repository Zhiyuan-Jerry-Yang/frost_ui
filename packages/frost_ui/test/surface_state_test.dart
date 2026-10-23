import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'support.dart';

void main() {
  testWidgets('sheet theme changes retain form binding, editing State, value and focus', (tester) async {
    var brightness = Brightness.dark;
    late StateSetter update;
    final text = TextEditingController();
    final focus = FocusNode();
    var submits = 0;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, set) {
          update = set;
          return frostTestApp(
            Builder(
              builder: (context) => FrostButton(
                label: 'Open',
                onPressed: () => showFrostFormDialog(
                  context: context,
                  title: 'Edit',
                  submitLabel: 'Save',
                  sections: [FrostTextField(label: 'Name', controller: text, focusNode: focus)],
                  onSubmit: () {
                    submits++;
                    return true;
                  },
                ),
              ),
            ),
            brightness: brightness,
          );
        },
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Retained value');
    final editing = tester.state<EditableTextState>(find.byType(EditableText));
    final form = tester.state(find.byType(FrostForm));
    for (final next in [Brightness.light, Brightness.dark, Brightness.light]) {
      update(() => brightness = next);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.state(find.byType(FrostForm)), same(form));
      expect(tester.state<EditableTextState>(find.byType(EditableText)), same(editing));
      expect(text.text, 'Retained value');
      expect(focus.hasPrimaryFocus, isTrue);
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(submits, 1);
    expect(find.byType(FrostDialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
    text.dispose();
    focus.dispose();
  });
  testWidgets('material, clipping and transparency changes retain the same form subtree', (tester) async {
    final controller = FrostFormController();
    final text = TextEditingController(text: 'Retained');
    final focus = FocusNode();
    Widget host(FrostSurfaceRole role, bool solid, bool continuous) {
      final config = testConfig.copyWith(continuousCorners: continuous);
      return FrostScope(
        config: config,
        reduceTransparency: solid,
        child: MaterialApp(
          theme: FrostTheme.build(config: config, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en')),
          home: Center(
            child: SizedBox(
              width: 300,
              child: FrostSurface(
                role: role,
                child: FrostForm(
                  controller: controller,
                  onSubmit: () => true,
                  children: [FrostTextField(label: 'Name', controller: text, focusNode: focus)],
                ),
              ),
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(host(FrostSurfaceRole.sheet, false, true));
    await tester.pumpAndSettle();
    focus.requestFocus();
    await tester.pump();
    final form = tester.state(find.byType(FrostForm));
    final editing = tester.state<EditableTextState>(find.byType(EditableText));
    for (final (role, solid, continuous) in [
      (FrostSurfaceRole.sheet, true, false),
      (FrostSurfaceRole.overlay, false, true),
      (FrostSurfaceRole.panel, false, false),
      (FrostSurfaceRole.base, false, true),
      (FrostSurfaceRole.module, false, true),
    ]) {
      await tester.pumpWidget(host(role, solid, continuous));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.state(find.byType(FrostForm)), same(form));
      expect(tester.state<EditableTextState>(find.byType(EditableText)), same(editing));
      expect(focus.hasPrimaryFocus, isTrue);
      expect(text.text, 'Retained');
    }
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    text.dispose();
    focus.dispose();
  });
}
