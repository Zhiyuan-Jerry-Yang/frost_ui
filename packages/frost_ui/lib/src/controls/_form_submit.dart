import 'package:flutter/widgets.dart';

/// Internal override for field completion in a composed submit surface.
/// Controller.submit bypasses this scope, preventing recursive submission.
class FrostFormSubmitScope extends InheritedWidget {
  const FrostFormSubmitScope({required this.submit, required super.child, super.key});
  final Future<bool> Function() submit;
  static Future<bool> Function()? maybeOf(BuildContext context) => context.getInheritedWidgetOfExactType<FrostFormSubmitScope>()?.submit;
  @override
  bool updateShouldNotify(FrostFormSubmitScope oldWidget) => submit != oldWidget.submit;
}
