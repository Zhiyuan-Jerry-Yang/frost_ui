import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

void main() {
  test('7B APIs need only widgets and frost_ui', () {
    final controller = FrostPagerController()..jumpTo(2);
    controller.animateTo(0);
    const viewer = FrostDetailPage<void>(opaque: false, child: SizedBox());
    expect(viewer.opaque, isFalse);
    expect(const FrostDetailPage<void>(child: SizedBox()).opaque, isTrue);
    final widgets = <Widget>[
      FrostPager(
        controller: controller,
        itemCount: 3,
        itemBuilder: (_, _) => const SizedBox(),
        initialPage: 1,
        onPageChanged: (_) {},
        showsIndicator: true,
        indicatorPlacement: FrostPageIndicatorPlacement.overlay,
      ),
      FrostPageIndicator(count: 3, current: 1, onSelected: (_) {}, onMedia: true),
      FrostInspector(inspector: const SizedBox(), open: false, onOpenChanged: (_) {}, title: 'Info', width: 320, child: const SizedBox()),
      FrostSplitView(primary: const SizedBox(), secondary: const SizedBox(), onCloseSecondary: () {}, initialPrimaryWidth: 320, resizable: true),
    ];
    expect(widgets, hasLength(4));
    expect(controller.page, 0);
    controller.dispose();
  });
}
