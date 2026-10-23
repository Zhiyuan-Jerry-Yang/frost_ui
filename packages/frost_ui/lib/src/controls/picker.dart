import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../lists/_contiguous_rows.dart';
import '../lists/_row_scope.dart';
import '../lists/list_row.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../motion/spring.dart';
import '../overlays/_menu_target.dart';
import '../overlays/_value_picker.dart';
import '../overlays/tooltip.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart' show FrostIcon;
import '_button_control.dart';
import '_button_types.dart';
import '_choice_mark.dart';
import '_control_surfaces.dart';
import '_field_layout.dart';
import '_field_trigger.dart';
import '_picker_row_scope.dart';
import '_toolbar_geometry.dart';
import 'color_swatch.dart';
import 'form.dart';
import 'picker_option.dart';

part '_picker_inline.dart';
part '_picker_layout.dart';
part '_picker_menu.dart';
part '_picker_palette.dart';
part '_picker_segments.dart';

enum FrostPickerStyle { auto, menu, segmented, inline, palette }

/// A controlled, mutually exclusive value choice. Auto chooses palettes first,
/// then up to four subtitle-free segments when their real layout fits.
/// Rows always choose menus; toolbar menus stay anchored at compact widths.
/// Values must be distinct. An unmatched value leaves the group unselected;
/// null matches a nullable option's null value just like any other value.
/// Errors do not change the selected style. Menu errors outline the field;
/// other styles show supporting error text without outlining the group.
class FrostPicker<T> extends StatefulWidget {
  const FrostPicker({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.label,
    this.style = FrostPickerStyle.auto,
    this.size,
    this.error,
    super.key,
  }) : trailingSwatch = null,
       _iconOnly = false;
  const FrostPicker.menu({required this.options, required this.value, required this.onChanged, required this.label, this.size, this.error, super.key})
    : style = FrostPickerStyle.menu,
      trailingSwatch = null,
      _iconOnly = false;
  const FrostPicker.segmented({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.label,
    this.size,
    this.error,
    bool iconOnly = false,
    super.key,
  }) : style = FrostPickerStyle.segmented,
       trailingSwatch = null,
       // Keep the public parameter name independent from private storage.
       // ignore: prefer_initializing_formals
       _iconOnly = iconOnly;
  const FrostPicker.inline({required this.options, required this.value, required this.onChanged, required this.label, this.size, this.error, super.key})
    : style = FrostPickerStyle.inline,
      trailingSwatch = null,
      _iconOnly = false;
  const FrostPicker.palette({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.label,
    this.size,
    this.error,
    this.trailingSwatch,
    super.key,
  }) : style = FrostPickerStyle.palette,
       _iconOnly = false;

  /// Optional final palette action, sharing arrow traversal and the group Tab
  /// stop. Its callback runs on activation, never when arrows merely focus it.
  /// App owns selected when the current custom colour is outside preset values.
  final FrostColorSwatch? trailingSwatch;
  final List<FrostPickerOption<T>> options;
  final T? value;
  final ValueChanged<T>? onChanged;
  final String label;
  final FrostPickerStyle style;
  final FrostControlSize? size;
  final String? error;
  final bool _iconOnly;
  @override
  State<FrostPicker<T>> createState() => _PickerState<T>();
}

class _PickerState<T> extends State<FrostPicker<T>> {
  final _nodes = <FocusNode>[];
  final _identity = FrostLayoutIdentity();
  final _layout = _PickerLayoutHandle();
  FocusNode? _menuFocus;
  FrostFormCoordinator? _form;
  late final _formField = FrostFormFieldHandle(context: context, focusOf: () => _focusTarget, errorOf: () => widget.error != null, enabledOf: () => _enabled);
  int? _active;
  int _thumbIndex = 0;
  bool get _enabled => widget.onChanged != null && FrostControlScope.enabledOf(context) && widget.options.isNotEmpty;
  int get _itemCount => widget.options.length + (widget.trailingSwatch == null ? 0 : 1);
  FocusNode _node(int index) => index < widget.options.length ? _nodes[index] : widget.trailingSwatch?.focusNode ?? _nodes[index];
  bool _itemEnabled(int index) => index < widget.options.length ? widget.options[index].enabled : widget.trailingSwatch?.onPressed != null;
  int? get _selected {
    if (widget.trailingSwatch?.selected ?? false) return null;
    final index = widget.options.indexWhere((option) => option.value == widget.value);
    return index < 0 ? null : index;
  }

  int? get _tabIndex {
    if (!_enabled) return null;
    if (_active case final active? when active < _itemCount && _itemEnabled(active)) return active;
    if (widget.trailingSwatch case final swatch? when swatch.selected && swatch.onPressed != null) return widget.options.length;
    if (_selected case final selected? when widget.options[selected].enabled) return selected;
    final first = widget.options.indexWhere((option) => option.enabled);
    return first < 0 ? null : first;
  }

  FocusNode? get _focusTarget => _layout.style == FrostPickerStyle.menu ? _menuFocus : (_tabIndex == null ? null : _node(_tabIndex!));
  void _syncNodes() {
    while (_nodes.length < _itemCount) {
      _nodes.add(FocusNode());
    }
    while (_nodes.length > _itemCount) {
      _nodes.removeLast().dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncNodes();
    _thumbIndex = _selected ?? 0;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final form = FrostFormScope.maybeOf(context);
    if (_form != form) {
      _form?.unregister(_formField);
      _form = form;
      _form?.register(_formField);
    }
    _formField.order = FrostFormOrder.of(context);
  }

  @override
  void didUpdateWidget(FrostPicker<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncNodes();
    if (oldWidget.value != widget.value) _active = _selected;
    if (widget.onChanged == null) _active = null;
    if (_selected case final selected?) _thumbIndex = selected;
  }

  @override
  void dispose() {
    _form?.unregister(_formField);
    for (final node in _nodes) {
      node.dispose();
    }
    _identity.dispose();
    super.dispose();
  }

  void _choose(int index, {bool activate = true}) {
    if (!_enabled || !_itemEnabled(index)) return;
    setState(() => _active = index);
    _node(index).requestFocus();
    if (index == widget.options.length) {
      if (activate) widget.trailingSwatch?.onPressed?.call();
      return;
    }
    if (widget.options[index].value != widget.value || _selected == null) widget.onChanged!(widget.options[index].value);
  }

  KeyEventResult _key(FocusNode _, KeyEvent event) {
    if (!_enabled || event is KeyUpEvent || widget.options.isEmpty) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final direction = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => 1,
      LogicalKeyboardKey.arrowUp => -1,
      LogicalKeyboardKey.arrowRight => rtl ? -1 : 1,
      LogicalKeyboardKey.arrowLeft => rtl ? 1 : -1,
      _ => 0,
    };
    if (direction == 0) return KeyEventResult.ignored;
    var index = List.generate(_itemCount, _node).indexWhere((node) => node.hasFocus);
    if (index < 0) index = _tabIndex ?? 0;
    for (var tried = 0; tried < _itemCount; tried++) {
      index = (index + direction) % _itemCount;
      if (_itemEnabled(index)) {
        _choose(index, activate: false);
        break;
      }
    }
    return KeyEventResult.handled;
  }

  Widget _body(BuildContext context, FrostPickerStyle style, {bool measure = false}) {
    final content = switch (style) {
      FrostPickerStyle.segmented => _PickerSegments<T>(owner: this, measurement: measure),
      FrostPickerStyle.inline => _PickerInline<T>(owner: this),
      FrostPickerStyle.palette => _PickerPalette<T>(owner: this),
      _ => _PickerMenu<T>(owner: this, measurement: measure),
    };
    if (style == FrostPickerStyle.menu) return content;
    final group = Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.label,
      child: Focus(canRequestFocus: false, skipTraversal: true, onKeyEvent: measure ? null : _key, child: content),
    );
    // Group controls keep their intrinsic width, including in toolbar probes.
    return FrostFieldLayout(stretch: false, error: measure ? null : widget.error, enabled: _enabled, supportingPresence: true, child: group);
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.options.map((option) => option.value).toSet().length == widget.options.length);
    assert(!widget._iconOnly || widget.options.every((option) => option.icon != null));
    final row = FrostPickerRowScope.of(context);
    var style = widget.style;
    if (style == FrostPickerStyle.auto) {
      if (row || widget.options.isEmpty) {
        style = FrostPickerStyle.menu;
      } else if (widget.options.every((option) => option.color != null)) {
        style = FrostPickerStyle.palette;
      } else if (widget.options.length > 4 || widget.options.any((option) => option.subtitle != null)) {
        style = FrostPickerStyle.menu;
      }
    }
    if (style == FrostPickerStyle.palette) assert(widget.options.every((option) => option.color != null));
    if (style != FrostPickerStyle.auto) _layout.style = style;
    return FrostControlScope(
      size: widget.size,
      child: Builder(
        builder: (context) => style == FrostPickerStyle.auto
            ? FrostLayoutCrossfade(
                layoutIdentity: _identity,
                child: _PickerAutoLayout(
                  identity: _identity,
                  handle: _layout,
                  direction: Directionality.of(context),
                  children: [
                    ExcludeFocus(
                      child: ExcludeSemantics(child: TickerMode(enabled: false, child: _body(context, FrostPickerStyle.segmented, measure: true))),
                    ),
                    LayoutBuilder(builder: (context, constraints) => _body(context, (constraints as _PickerConstraints).style)),
                  ],
                ),
              )
            : _body(context, style),
      ),
    );
  }
}
