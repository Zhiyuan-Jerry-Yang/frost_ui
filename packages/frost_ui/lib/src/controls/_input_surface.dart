import 'package:flutter/material.dart';

import '../primitives/_click_surface_visuals.dart';
import '../primitives/click_surface.dart';

/// Shared click input with delegated visuals sized by the control, not its hit
/// box. Focus rings therefore surround the visual mark while input stays large.
class FrostInputSurface extends StatefulWidget {
  const FrostInputSurface({required this.onTap, required this.builder, this.onPressedChange, this.focusNode, super.key});
  final VoidCallback? onTap;
  final Widget Function(BuildContext context, Set<WidgetState> states) builder;
  final ValueChanged<bool>? onPressedChange;
  final FocusNode? focusNode;
  @override
  State<FrostInputSurface> createState() => _InputSurfaceState();
}

class _InputSurfaceState extends State<FrostInputSurface> {
  bool _hovered = false, _pressed = false, _focused = false;
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_highlightChanged);
  }

  void _highlightChanged(FocusHighlightMode _) {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(FrostInputSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onTap == null) _pressed = false;
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_highlightChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final states = <WidgetState>{
      if (!enabled) WidgetState.disabled,
      if (enabled && _hovered) WidgetState.hovered,
      if (enabled && _pressed) WidgetState.pressed,
      if (enabled && _focused) WidgetState.focused,
    };
    return FrostClickSurfaceVisuals(
      child: FrostClickSurface(
        focusNode: widget.focusNode,
        onTap: widget.onTap,
        onHover: (value) => setState(() => _hovered = value),
        onFocusChange: (value) => setState(() => _focused = value),
        onPressedChange: (value) {
          setState(() => _pressed = value && enabled);
          widget.onPressedChange?.call(value);
        },
        child: widget.builder(context, states),
      ),
    );
  }
}
