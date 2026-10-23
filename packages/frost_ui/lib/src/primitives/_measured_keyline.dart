import 'package:flutter/widgets.dart';

/// A preceding row's text box, resolved by the divider during paint after all
/// siblings have laid out. No post-frame geometry repair is necessary.
class FrostMeasuredKeyline extends InheritedWidget {
  const FrostMeasuredKeyline({required this.target, required super.child, super.key});
  final GlobalKey target;
  static GlobalKey? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostMeasuredKeyline>()?.target;
  @override
  bool updateShouldNotify(FrostMeasuredKeyline oldWidget) => target != oldWidget.target;
}
