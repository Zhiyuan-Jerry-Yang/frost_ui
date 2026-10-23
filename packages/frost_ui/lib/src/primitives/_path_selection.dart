import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A displayed path is selected and copied as its complete original value.
class FrostPathSelection extends MultiSelectableSelectionContainerDelegate {
  FrostPathSelection(this.path);
  final String Function() path;
  @override
  void ensureChildUpdated(Selectable selectable) {}
  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) =>
      super.dispatchSelectionEvent(event is ClearSelectionEvent ? event : const SelectAllSelectionEvent());
  @override
  SelectedContent? getSelectedContent() => super.getSelectedContent() == null ? null : SelectedContent(plainText: path());
}
