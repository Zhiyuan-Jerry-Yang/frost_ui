import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// Tabs share fixed indicator geometry with the Material migration fallback.
const frostTabIndicatorWidth = 20.0;
const frostTabIndicatorHeight = 3.0;
const frostTabInset = 12.0;
const frostTabIconGap = 6.0;

/// A fixed-width mark. Optional offsets center it under text after an icon.
class FrostTabIndicator extends Decoration {
  const FrostTabIndicator({required this.color, this.textOffsets = const [], this.progress});
  final Color color;
  final List<double> textOffsets;
  final Animation<double>? progress;
  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _TabIndicatorPainter(this, onChanged);
}

class _TabIndicatorPainter extends BoxPainter {
  _TabIndicatorPainter(this.decoration, super.onChanged);
  final FrostTabIndicator decoration;
  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final offsets = decoration.textOffsets;
    final value = (decoration.progress?.value ?? 0).clamp(0.0, (offsets.length - 1).clamp(0, double.infinity).toDouble());
    final start = value.floor(), end = value.ceil();
    final shift = offsets.isEmpty ? 0.0 : ui.lerpDouble(offsets[start], offsets[end], value - start)!;
    final size = configuration.size!;
    final rect = Rect.fromLTWH(
      offset.dx + size.width / 2 + shift - frostTabIndicatorWidth / 2,
      offset.dy + size.height - frostTabIndicatorHeight,
      frostTabIndicatorWidth,
      frostTabIndicatorHeight,
    );
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(frostTabIndicatorHeight / 2)), Paint()..color = decoration.color);
  }
}
