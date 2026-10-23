import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';

import '../controls/_button_control.dart';
import '../controls/_button_types.dart';
import '../foundation/control_scope.dart';
import '../foundation/metrics.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/layout_crossfade.dart';
import '../motion/rolling_text.dart';
import '../motion/spring.dart';
import '../primitives/icon.dart';
import '../primitives/presence.dart';

// The first confirmation peak is twenty percent above the resting icon size.
const _confirmationAmplitude = .2;

class FrostToggleButton extends StatelessWidget {
  const FrostToggleButton({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onChanged,
    required this.label,
    this.tint,
    this.size,
    super.key,
  });
  final FrostIconData icon, selectedIcon;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final String label;

  /// Supply a semantic Frost colour (for example negativeInk), never an
  /// arbitrary colour. Null inherits accentInk.
  final Color? tint;
  final FrostControlSize? size;
  @override
  Widget build(BuildContext context) =>
      _SocialAction(icon: icon, selectedIcon: selectedIcon, selected: selected, onChanged: onChanged, label: label, tint: tint, size: size);
}

class FrostActionCount extends StatelessWidget {
  const FrostActionCount({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.count,
    required this.onChanged,
    required this.label,
    this.tint,
    this.format,
    super.key,
  }) : assert(count >= 0);
  final FrostIconData icon, selectedIcon;
  final bool selected;
  final int count;
  final ValueChanged<bool>? onChanged;
  final String label;

  /// Supply a semantic Frost colour, never an arbitrary colour.
  final Color? tint;
  final String Function(int count)? format;
  @override
  Widget build(BuildContext context) =>
      _SocialAction(icon: icon, selectedIcon: selectedIcon, selected: selected, onChanged: onChanged, label: label, tint: tint, count: count, format: format);
}

/// Shared private implementation; public wrappers supply only semantic data.
class _SocialAction extends StatefulWidget {
  const _SocialAction({
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onChanged,
    required this.label,
    this.tint,
    this.size,
    this.count,
    this.format,
  });
  final FrostIconData icon, selectedIcon;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final String label;
  final Color? tint;
  final FrostControlSize? size;
  final int? count;
  final String Function(int count)? format;
  @override
  State<_SocialAction> createState() => _SocialActionState();
}

class _SocialActionState extends State<_SocialAction> with SingleTickerProviderStateMixin {
  late final _pop = AnimationController.unbounded(vsync: this, value: 1);
  late String _lastCount = _formatted;
  String get _formatted => widget.format?.call(widget.count ?? 0) ?? (widget.count ?? 0).toString();
  // One positive lobe of a critical spring: its peak is amplitude at 1/omega.
  // Coalescing retriggers prevents confirmation energy from accumulating.
  double get _impulse => _confirmationAmplitude * math.e * math.sqrt(FrostMotion.snappy.stiffness / FrostMotion.snappy.mass);

  @override
  void didUpdateWidget(_SocialAction oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.count ?? 0) > 0) _lastCount = _formatted;
    if (oldWidget.selected == widget.selected) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pop.value = 1;
      return;
    }
    if (widget.selected) {
      if (!_pop.isAnimating) {
        _pop.animateWith(SpringSimulation(FrostMotion.snappy, _pop.value, 1, _impulse, snapToEnd: true));
      }
    } else {
      FrostMotion.springTo(context, _pop, 1, FrostMotion.snappy);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _pop.value = 1;
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size ?? FrostControlScope.sizeOf(context);
    final enabled = widget.onChanged != null && FrostControlScope.enabledOf(context);
    final tokens = FrostThemeTokens.of(context);
    final ink = widget.selected ? widget.tint ?? tokens.accentInk : tokens.textPrimary;
    final action = enabled ? () => widget.onChanged!(!widget.selected) : null;
    final height = size.height(context);
    final iconSize = size.iconSize;
    return Semantics(
      label: widget.label,
      value: (widget.count ?? 0) > 0 ? _formatted : null,
      button: true,
      toggled: widget.selected,
      enabled: enabled,
      onTap: action,
      excludeSemantics: true,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: ink),
        duration: FrostMotion.duration(context, FrostMotion.hover),
        builder: (context, colour, _) => FrostButtonControl(
          label: widget.label,
          onPressed: action,
          size: size,
          variant: FrostButtonVariant.plain,
          iconStyle: widget.count == null ? FrostIconButtonStyle.plain : null,
          showsLabel: widget.count != null,
          iconWidget: ScaleTransition(
            scale: _pop,
            child: FrostLayoutCrossfade(
              layoutIdentity: widget.selected ? widget.selectedIcon : widget.icon,
              settleDuration: Duration.zero,
              child: FrostIcon(widget.selected ? widget.selectedIcon : widget.icon, size: iconSize, color: colour),
            ),
          ),
          labelWidget: widget.count == null ? null : _count(context, colour!),
          textRole: FrostTextRole.footnote,
          geometry: FrostButtonGeometry(
            horizontalInset: (height - iconSize) / 2,
            edgeBleed: (height - iconSize) / 2,
            verticalInset: 0,
            minimumWidth: height,
            iconGap: 0,
            alignment: MainAxisAlignment.center,
          ),
        ),
      ),
    );
  }

  Widget _count(BuildContext context, Color colour) {
    final style = FrostTypography.of(context).style(FrostTextRole.footnote, numeric: true).copyWith(color: colour);
    final painter = TextPainter(
      text: TextSpan(text: _lastCount, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width + FrostGap.inline;
    painter.dispose();
    return FrostSpringBuilder(
      value: widget.count == 0 ? 0 : width,
      spring: FrostMotion.standard,
      child: SizedBox(
        width: width,
        child: FrostPresence(
          visible: widget.count != 0,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: FrostGap.inline),
              FrostRollingText(_lastCount, style: style),
            ],
          ),
        ),
      ),
      builder: (context, value, child) => ClipRect(
        child: SizedBox(
          width: math.max(0, value),
          child: OverflowBox(fit: OverflowBoxFit.deferToChild, alignment: AlignmentDirectional.centerStart, minWidth: width, maxWidth: width, child: child),
        ),
      ),
    );
  }
}
