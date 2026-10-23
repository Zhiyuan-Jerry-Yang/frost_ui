import 'package:flutter/widgets.dart';

import 'sizes.dart';

/// Defaults for future controls; nullable fields inherit independently.
class FrostControlScope extends InheritedWidget {
  const FrostControlScope({this.size, this.enabled, this.toolbar, required super.child, super.key});
  final FrostControlSize? size;
  final bool? enabled;
  final bool? toolbar;

  static bool toolbarOf(BuildContext context) {
    var result = false;
    context.visitAncestorElements((element) {
      if (element is InheritedElement && element.widget is FrostControlScope) {
        final scope = context.dependOnInheritedElement(element) as FrostControlScope;
        if (scope.toolbar case final toolbar?) {
          result = toolbar;
          return false;
        }
      }
      return true;
    });
    return result;
  }

  static FrostControlSize sizeOf(BuildContext context) {
    var result = FrostControlSize.regular;
    context.visitAncestorElements((element) {
      if (element is InheritedElement && element.widget is FrostControlScope) {
        final scope = context.dependOnInheritedElement(element) as FrostControlScope;
        if (scope.size case final size?) {
          result = size;
          return false;
        }
      }
      return true;
    });
    return result;
  }

  static bool enabledOf(BuildContext context) {
    var result = true;
    context.visitAncestorElements((element) {
      if (element is InheritedElement && element.widget is FrostControlScope) {
        final scope = context.dependOnInheritedElement(element) as FrostControlScope;
        if (scope.enabled case final enabled?) {
          result = enabled;
          return false;
        }
      }
      return true;
    });
    return result;
  }

  @override
  bool updateShouldNotify(FrostControlScope oldWidget) => size != oldWidget.size || enabled != oldWidget.enabled || toolbar != oldWidget.toolbar;
}
