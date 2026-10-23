import 'package:flutter/widgets.dart';

/// Value menus match their trigger width; a settings row anchors to its value.
class FrostMenuTarget extends InheritedWidget {
  const FrostMenuTarget({this.targetKey, required super.child, super.key});
  final GlobalKey? targetKey;

  static bool matchesWidthOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostMenuTarget>() != null;

  static Rect? rectOf(BuildContext context) {
    final key = context.dependOnInheritedWidgetOfExactType<FrostMenuTarget>()?.targetKey;
    if (key == null) return null;
    final target = key.currentContext?.findRenderObject();
    final overlay = Overlay.of(context).context.findRenderObject();
    if (target is! RenderBox || !target.hasSize || overlay == null) return null;
    return target.localToGlobal(Offset.zero, ancestor: overlay) & target.size;
  }

  @override
  bool updateShouldNotify(FrostMenuTarget oldWidget) => targetKey != oldWidget.targetKey;
}
