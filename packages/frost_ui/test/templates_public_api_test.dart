import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('7C APIs compile with only widgets and frost_ui', () {
    final widgets = <Widget>[
      FrostBrowseLayout(header: const SizedBox(), filterBar: const SizedBox(), slivers: const [], empty: const SizedBox(), isEmpty: true),
      const FrostDetailLayout(
        stackBelow: FrostSizeClass.expanded,
        stage: SizedBox(),
        primary: SizedBox(),
        actions: SizedBox(),
        modules: [],
        sections: [],
        technical: SizedBox(),
        header: SizedBox(),
      ),
      FrostCollectionLayout(
        header: const SizedBox(),
        toolbar: const SizedBox(),
        stats: const [FrostStat(value: '1', caption: 'items')],
        slivers: const [],
      ),
    ];
    final controller = FrostFormDialogController(errorSummary: 'error')..errorSummary = null;
    Future<bool> open(BuildContext context) => showFrostFormDialog(
      context: context,
      title: 'Form',
      sections: const [FrostFormSection(children: [])],
      onSubmit: () => true,
      submitLabel: 'Save',
      cancelLabel: 'Cancel',
      errorSummary: 'error',
      controller: controller,
      size: FrostDialogSize.wide,
    );
    expect(open, isNotNull);
    controller.dispose();
    expect(widgets, hasLength(3));
  });
}
