// Deliberately no material.dart import: these mechanisms belong to the public
// Frost entry point, while normal Flutter layout remains widgets.dart.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  testWidgets('tab controller and view compile through frost_ui only', (tester) async {
    final controller = TabController(length: 2, vsync: tester);
    final bar = FrostTabBar(
      controller: controller,
      tabs: const [
        FrostTab(label: 'A'),
        FrostTab(label: 'B'),
      ],
    );
    final view = TabBarView(controller: controller, children: const [SizedBox(), SizedBox()]);
    final defaults = DefaultTabController(length: 2, child: Column(children: [bar, view]));
    expect(defaults.length, 2);
    expect(bar, isNot(isA<PreferredSizeWidget>()));
    controller.dispose();
  });
}
