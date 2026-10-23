import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'sizes.dart';

/// Spacing and control sizes chosen by the user's density setting. Text sizes
/// never follow density; they stay with the app's reading settings.
///
/// Carried in the theme built by `FrostTheme.build`; read it with [of].
@immutable
class FrostDensity extends ThemeExtension<FrostDensity> {
  const FrostDensity._({
    required this.name,
    required this.pageInset,
    required this.rowPadding,
    required this.railWidth,
    this.platform = TargetPlatform.windows,
  });

  /// Touch-sized spacing: the design's original values.
  static const comfortable = FrostDensity._(name: 'comfortable', pageInset: 16, rowPadding: 16, railWidth: 80);

  /// Pointer-sized spacing for desktop windows.
  static const compact = FrostDensity._(name: 'compact', pageInset: 12, rowPadding: 12, railWidth: 56);

  static const values = [comfortable, compact];

  final String name;
  final TargetPlatform platform;
  bool get _pointer => platform == TargetPlatform.windows || platform == TargetPlatform.macOS || platform == TargetPlatform.linux;
  double heightFor(FrostControlSize size) => size.visualHeight(touch: !_pointer || name == comfortable.name);
  FrostDensity forPlatform(TargetPlatform value) =>
      value == platform ? this : FrostDensity._(name: name, pageInset: pageInset, rowPadding: rowPadding, railWidth: railWidth, platform: value);

  /// Height of compact targets: navigation and menu rows, small buttons.
  double get targetHeight => math.max(heightFor(FrostControlSize.compact), FrostControlSize.minimumHitHeight(touch: !_pointer));

  /// Height of icon buttons and full-size buttons.
  double get controlHeight => heightFor(FrostControlSize.regular);

  /// Height of text fields and selectors where input is by pointer; touch
  /// platforms keep [controlHeight] whatever the density.
  double get pointerFieldHeight => heightFor(FrostControlSize.regular);

  /// Distance between a page's content and its edges.
  final double pageInset;

  /// Vertical padding of a list row.
  final double rowPadding;

  /// Width of a collapsed flush sidebar.
  final double railWidth;

  static FrostDensity of(BuildContext context) => Theme.of(context).extension<FrostDensity>() ?? comfortable.forPlatform(Theme.of(context).platform);

  @override
  FrostDensity copyWith() => this;

  @override
  FrostDensity lerp(ThemeExtension<FrostDensity>? other, double t) => t < .5 || other is! FrostDensity ? this : other;

  @override
  String toString() => 'FrostDensity.$name';
}
