import 'dart:async';

import 'package:flutter/material.dart';

import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/typography.dart';
import '../primitives/status_glyph.dart';
import '_button_control.dart';
import '_button_types.dart';

export '_button_types.dart';
export 'switch.dart';

// Hold begins after the result stroke is complete, not when its Future ends.
const _buttonResultHold = Duration(milliseconds: 1200);

class FrostButton extends StatefulWidget {
  const FrostButton({
    required this.label,
    this.onPressed,
    this.onPressedAsync,
    this.icon,
    this.labelWidget,
    this.variant = FrostButtonVariant.standard,
    this.role = FrostButtonRole.normal,
    this.size,
    this.chevron = FrostButtonChevron.none,
    this.loading = false,
    this.tooltip,
    this.edgeAlignment,
    super.key,
  }) : assert(onPressed == null || onPressedAsync == null),
       assert(onPressedAsync == null || !loading),
       assert(edgeAlignment == null || variant == FrostButtonVariant.plain),
       style = null,
       selected = null,
       _quiet = false;

  /// A secondary text action with footnote typography and no resting fill.
  /// It keeps the ordinary density-dependent hit target, feedback and focus.
  const FrostButton.quiet({
    required this.label,
    this.onPressed,
    this.onPressedAsync,
    this.size,
    this.loading = false,
    this.tooltip,
    this.edgeAlignment,
    super.key,
  }) : assert(onPressed == null || onPressedAsync == null),
       assert(onPressedAsync == null || !loading),
       icon = null,
       labelWidget = null,
       variant = FrostButtonVariant.plain,
       role = FrostButtonRole.normal,
       chevron = FrostButtonChevron.none,
       style = null,
       selected = null,
       _quiet = true;

  const FrostButton.icon({
    required FrostIconData this.icon,
    required this.label,
    this.onPressed,
    this.onPressedAsync,
    this.style = FrostIconButtonStyle.plain,
    this.role = FrostButtonRole.normal,
    this.size,
    this.selected,
    this.edgeAlignment,
    this.loading = false,
    this.tooltip,
    super.key,
  }) : assert(onPressed == null || onPressedAsync == null),
       assert(onPressedAsync == null || !loading),
       assert(edgeAlignment == null || style == FrostIconButtonStyle.plain),
       labelWidget = null,
       variant = FrostButtonVariant.plain,
       chevron = FrostButtonChevron.none,
       _quiet = false;

  /// Available on plain icons and plain/quiet text actions. Null retains
  /// ordinary layout; a shared row aligns its terminal plain icon automatically.
  /// Place at a shared content/container keyline; full padding is preserved.
  final FrostButtonEdgeAlignment? edgeAlignment;
  final bool _quiet;
  final String label;
  final VoidCallback? onPressed;

  /// Runs one operation and owns its loading/result feedback. True succeeds,
  /// false fails; exceptions show failure and are reported through FlutterError.
  /// Loading and result feedback prevent repeat activation. The result remains
  /// for 1200 ms after drawing, then the original content returns. Disposed or
  /// disabled buttons discard a pending result. Do not combine with [loading].
  final Future<bool> Function()? onPressedAsync;
  final FrostIconData? icon;

  /// Dynamic text only (for example rolling numbers). The button supplies its
  /// DefaultTextStyle; do not use this slot to override typography or colours.
  final Widget? labelWidget;
  final FrostButtonVariant variant;
  final FrostButtonRole role;
  final FrostControlSize? size;
  final FrostButtonChevron chevron;
  final bool loading;
  final String? tooltip;
  final FrostIconButtonStyle? style;
  final bool? selected;

  @override
  State<FrostButton> createState() => _FrostButtonState();
}

class _FrostButtonState extends State<FrostButton> {
  bool _running = false;
  FrostStatusGlyphKind? _result;
  Timer? _hold;
  int _operation = 0;
  bool get _busy => _running || _result != null;

  Future<void> _activateAsync() async {
    if (_busy || widget.onPressedAsync == null) return;
    final operation = ++_operation;
    final invoke = widget.onPressedAsync!;
    setState(() => _running = true);
    bool success;
    try {
      success = await invoke();
    } catch (error, stack) {
      if (!mounted || operation != _operation) return;
      success = false;
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stack, library: 'frost_ui', context: ErrorDescription('while running a button action')),
      );
    }
    if (!mounted || operation != _operation) return;
    setState(() {
      _running = false;
      _result = success ? FrostStatusGlyphKind.success : FrostStatusGlyphKind.failure;
    });
  }

  void _resultDrawn(int operation) {
    if (!mounted || operation != _operation || _hold != null) return;
    _hold = Timer(_buttonResultHold, () {
      if (!mounted || operation != _operation) return;
      _hold = null;
      setState(() => _result = null);
    });
  }

  @override
  void didUpdateWidget(FrostButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onPressedAsync != null && widget.onPressedAsync == null) {
      _operation++;
      _hold?.cancel();
      _hold = null;
      _running = false;
      _result = null;
    }
  }

  @override
  void dispose() {
    _operation++;
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context);
    final size = widget.size ?? FrostControlScope.sizeOf(context);
    final operation = _operation;
    return FrostButtonControl(
      presentation: widget._quiet ? FrostButtonPresentation.quiet : FrostButtonPresentation.action,
      textRole: widget._quiet ? FrostTextRole.footnote : FrostTextRole.callout,
      label: widget.label,
      onPressed: widget.onPressedAsync == null ? widget.onPressed : _activateAsync,
      icon: widget.icon,
      labelWidget: widget.labelWidget,
      variant: widget.variant,
      role: widget.role,
      size: widget.size,
      chevron: widget.chevron,
      loading: widget.loading || _running,
      busy: _busy,
      feedback: _result == null
          ? null
          : FrostProgressResult(
              key: ValueKey(operation),
              result: _result,
              size: size == FrostControlSize.compact ? 16 : 20,
              onResultDrawn: () => _resultDrawn(operation),
            ),
      feedbackLabel: _result == null
          ? null
          : _result == FrostStatusGlyphKind.success
          ? labels.actionSucceeded
          : labels.actionFailed,
      tooltip: widget.tooltip,
      edgeAlignment: widget.edgeAlignment,
      iconStyle: widget.style,
      selected: widget.selected,
    );
  }
}
