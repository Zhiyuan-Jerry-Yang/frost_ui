import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'media_test_image.dart';

void main() {
  test('7A APIs need only widgets and frost_ui', () {
    final tag = FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 1.5, sourceRadius: BorderRadius.zero);
    final controller = FrostMediaViewportController()..reset();
    final widgets = <Widget>[
      const FrostOnMediaChromeScope(child: SizedBox()),
      const FrostMediaCard(media: SizedBox()),
      const FrostMediaImage(child: SizedBox()),
      FrostMediaCard.skeleton(aspectRatio: null, footer: '000000000000'),
      const FrostThumbnail(image: SizedBox(), size: FrostThumbnailSize.large, semanticLabel: 'Image'),
      FrostThumbnailStrip(itemCount: 1, itemBuilder: (_, _) => const SizedBox(), selectedIndex: null, onSelected: (_) {}),
      FrostMediaHeroSource(image: mediaTestImage, builder: (_, tag) => const SizedBox(), aspectRatio: 1, sourceRadius: BorderRadius.zero),
      FrostMediaHero(tag: tag, radius: BorderRadius.zero, child: const SizedBox()),
      FrostMediaViewport(controller: controller, onScaleChanged: (double scale) {}, background: const SizedBox(), child: const SizedBox()),
      FrostAmbientBackdrop.fromImage(image: const AssetImage('test'), child: const SizedBox()),
    ];
    expect(widgets, hasLength(10));
  });
}
