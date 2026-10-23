import 'package:flutter/widgets.dart';

const frostMobileBreakpoint = 600.0;
const frostTabletBreakpoint = 900.0;
const frostDesktopBreakpoint = 1200.0;

FrostSizeClass frostDefaultSizeClass(Size size) => FrostSizeLayout.fromSize(
  size,
  mobileBreakpoint: frostMobileBreakpoint,
  tabletBreakpoint: frostTabletBreakpoint,
  desktopBreakpoint: frostDesktopBreakpoint,
).sizeClass;

// Descendants use the window's navigation mode even after ContentViewport
// subtracts the sidebar or a detail pane constrains the available content width.
class FrostAdaptiveLayoutData extends InheritedWidget {
  const FrostAdaptiveLayoutData({required this.horizontal, required this.sizeClass, required super.child, super.key});
  final FrostSizeClass sizeClass;
  final bool horizontal;

  // Read the window scope before local viewports reduce MediaQuery width.
  static bool horizontalOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrostAdaptiveLayoutData>()?.horizontal ?? isHorizontalSize(MediaQuery.sizeOf(context));

  @override
  bool updateShouldNotify(FrostAdaptiveLayoutData oldWidget) => horizontal != oldWidget.horizontal || sizeClass != oldWidget.sizeClass;
}

enum FrostSizeClass {
  compact,
  medium,
  expanded,
  large;

  /// Default minimum width of this layout tier, usable against local space
  /// without reading the outer window's navigation classification.
  double get minimumWidth => switch (this) {
    compact => 0,
    medium => frostMobileBreakpoint,
    expanded => frostTabletBreakpoint,
    large => frostDesktopBreakpoint,
  };

  static FrostSizeClass of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrostAdaptiveLayoutData>()?.sizeClass ?? frostDefaultSizeClass(MediaQuery.sizeOf(context));
}

class FrostSizeLayout {
  const FrostSizeLayout({required this.size, required this.sizeClass});

  factory FrostSizeLayout.fromSize(Size size, {required double mobileBreakpoint, required double tabletBreakpoint, required double desktopBreakpoint}) {
    final width = size.width;
    final sizeClass = switch (width) {
      final value when value < mobileBreakpoint => FrostSizeClass.compact,
      final value when value < tabletBreakpoint => FrostSizeClass.medium,
      final value when value < desktopBreakpoint => FrostSizeClass.expanded,
      _ => FrostSizeClass.large,
    };

    return FrostSizeLayout(size: size, sizeClass: sizeClass);
  }

  final Size size;
  final FrostSizeClass sizeClass;

  double get width => size.width;

  double get height => size.height;

  double get shortestSide => size.shortestSide;

  bool get isCompact => sizeClass == FrostSizeClass.compact;

  bool get isMedium => sizeClass == FrostSizeClass.medium;

  bool get isExpanded => sizeClass == FrostSizeClass.expanded;

  bool get isLarge => sizeClass == FrostSizeClass.large;
}

/// Navigation responds to window width, even in a short or landscape window.
bool isHorizontalSize(Size size) => size.width >= frostMobileBreakpoint;
