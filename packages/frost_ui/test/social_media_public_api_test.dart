import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'media_test_image.dart';

void main() {
  test('social media public API uses widgets and frost_ui only', () {
    const image = AssetImage('app-owned.png');
    final card = FrostLinkCard(
      title: 'Title',
      description: 'Detail',
      url: Uri.parse('https://example.org'),
      image: image,
      style: FrostLinkCardStyle.large,
      onPressed: () {},
    );
    final skeleton = FrostLinkCard.skeleton(style: FrostLinkCardStyle.row, image: false, title: 'Title', description: null, host: 'example.org');
    final tag = FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 1, sourceRadius: FrostRadius.borderRadius(FrostRadius.md));
    final mosaic = FrostMediaMosaic(images: const [image], sizes: const [Size(1, 1)], onPressed: (_) {}, heroTag: (_) => tag, semanticLabel: (_) => 'Media');
    final bones = FrostMediaMosaic.skeleton(count: 2, sizes: const [null, null]);
    expect(card.style, FrostLinkCardStyle.large);
    expect(skeleton, isA<FrostLinkCard>());
    expect(mosaic.heroTag!(0), tag);
    expect(bones.images, isEmpty);
  });
}
