import 'package:flutter/widgets.dart';

/// Shares picker input focus without changing row content or geometry.
class FrostRowFocus extends InheritedWidget {
  const FrostRowFocus({required this.focusNode, required super.child, super.key});
  final FocusNode focusNode;
  static FocusNode? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostRowFocus>()?.focusNode;
  @override
  bool updateShouldNotify(FrostRowFocus oldWidget) => focusNode != oldWidget.focusNode;
}

/// Group placement and measured text anchor, never part of the public API.
class FrostRowPlacement extends InheritedWidget {
  const FrostRowPlacement({required this.textAnchor, required this.corners, required super.child, super.key});
  final GlobalKey textAnchor;
  final BorderRadius? corners;
  static FrostRowPlacement? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostRowPlacement>();
  @override
  bool updateShouldNotify(FrostRowPlacement oldWidget) => textAnchor != oldWidget.textAnchor || corners != oldWidget.corners;
}

/// List selection/highlight is presentation state owned by the list, while
/// activation falls back to the row when the list has no selection callback.
class FrostListItemScope extends InheritedWidget {
  const FrostListItemScope({
    required this.selected,
    this.reserveIconColumn = false,
    required this.highlighted,
    required this.onSelected,
    required this.handle,
    required this.viewportInset,
    required super.child,
    super.key,
  });
  final bool selected, highlighted, reserveIconColumn;
  final VoidCallback? onSelected;
  final FrostListItemHandle handle;
  final EdgeInsetsGeometry viewportInset;
  static FrostListItemScope? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostListItemScope>();
  @override
  bool updateShouldNotify(FrostListItemScope oldWidget) =>
      selected != oldWidget.selected ||
      reserveIconColumn != oldWidget.reserveIconColumn ||
      highlighted != oldWidget.highlighted ||
      onSelected != oldWidget.onSelected ||
      handle != oldWidget.handle ||
      viewportInset != oldWidget.viewportInset;
}

/// UI-only registration, without notifications or writes during build/layout.
class FrostListItemHandle {
  VoidCallback? activate;
}
