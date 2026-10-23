import 'package:flutter/widgets.dart';

/// Internal keyboard relay: a search field can drive the same lazy list while
/// retaining its own editing focus. No state notification occurs during layout.
class FrostListInputController<T> {
  KeyEventResult Function(KeyEvent event)? handle;
  Object? _owner;
  T? Function()? _keyboardItem;
  bool get attached => _owner != null;
  T? get keyboardItem => _keyboardItem?.call();
  void bind(Object owner, KeyEventResult Function(KeyEvent event) callback, T? Function() keyboardItem) {
    _owner = owner;
    _keyboardItem = keyboardItem;
    handle = callback;
  }

  void unbind(Object owner) {
    if (!identical(_owner, owner)) return;
    _owner = null;
    _keyboardItem = null;
    handle = null;
  }
}

class FrostListInput<T> extends InheritedWidget {
  const FrostListInput({required this.controller, required this.onHighlight, this.identity, this.footer, required super.child, super.key});
  final FrostListInputController<T> controller;
  // Status is part of the same lazy viewport but never a selectable item.
  final Widget? footer;
  final Object Function(T item)? identity;
  final void Function(T? item, int? index) onHighlight;
  static FrostListInput<T>? of<T>(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostListInput<T>>();
  @override
  bool updateShouldNotify(FrostListInput<T> oldWidget) =>
      controller != oldWidget.controller || onHighlight != oldWidget.onHighlight || footer != oldWidget.footer;
}
