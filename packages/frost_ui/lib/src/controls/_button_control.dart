import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../feedback/_skeleton_geometry.dart';
import '../feedback/activity_indicator.dart';
import '../feedback/loading_gate.dart';
import '../foundation/_ambient_material.dart';
import '../foundation/_control_dimming.dart';
import '../foundation/_focus_modality.dart';
import '../foundation/color_math.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/feedback.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../overlays/tooltip.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_focus_outline.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';
import '../surface/_window_background.dart';
import '_button_types.dart';
import '_field_options.dart';

// Public text buttons use these insets, independently of toolbar edge geometry.
const _compactTextInset = 12.0;
const _regularTextInset = 16.0;
const _largeTextInset = 20.0;

/// Internal geometry shared by section edges and the one button renderer.
double frostButtonTextInset(FrostControlSize size) => switch (size) {
  FrostControlSize.compact => _compactTextInset,
  FrostControlSize.regular => _regularTextInset,
  FrostControlSize.large => _largeTextInset,
};
// Compact icon/label pairs are closer; chevrons always have the inline gap.
const _compactIconGap = 6.0;
const _regularIconGap = 8.0;
const _chevronGap = 4.0;
// Keyboard rings grow with the surface's corners to remain concentric.
const _focusOutset = 3.0;
// Selected icons begin a small pop only after a mounted selection changes.
const _disabledOpacity = .38;

/// Library-only geometry override. It carries no paint or interaction policy.
class FrostButtonGeometry {
  const FrostButtonGeometry({
    required this.horizontalInset,
    required this.verticalInset,
    required this.minimumWidth,
    required this.alignment,
    this.visualHeight,
    this.cornerRadius,
    this.iconSize,
    this.iconGap,
    this.maximumHitHeight,
    this.edgeBleed,
  });
  final double horizontalInset, verticalInset, minimumWidth;
  final double? visualHeight, edgeBleed;
  final double? cornerRadius, iconSize, maximumHitHeight, iconGap;
  final MainAxisAlignment alignment;
}

/// Library-only semantic presentation; geometry remains a numeric configuration.
enum FrostButtonPresentation { action, field, content, link, quiet }

/// The single renderer/input path for public buttons and toolbar controls.
/// This type and its geometry configuration are not exported by frost_ui.dart.
class FrostButtonControl extends StatefulWidget {
  const FrostButtonControl({
    required this.label,
    required this.onPressed,
    this.labelWidget,
    this.semanticLabel,
    this.iconWidget,
    this.trailing,
    this.icon,
    this.variant = FrostButtonVariant.standard,
    this.role = FrostButtonRole.normal,
    this.size,
    this.chevron = FrostButtonChevron.none,
    this.iconStyle,
    this.selected,
    this.loading = false,
    this.busy = false,
    this.feedback,
    this.feedbackLabel,
    this.tooltip,
    this.edgeAlignment,
    this.focusNode,
    this.textRole = FrostTextRole.callout,
    this.showsLabel = true,
    this.truncates = true,
    this.geometry,
    this.presentation = FrostButtonPresentation.action,
    this.autofocus = false,
    this.wrapsLabel = false,
    super.key,
  });
  final String label;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final Widget? labelWidget, iconWidget, trailing;
  final FrostIconData? icon;
  final FrostButtonVariant variant;
  final FrostButtonRole role;
  final FrostControlSize? size;
  final FrostButtonChevron chevron;
  final FrostIconButtonStyle? iconStyle;
  final bool? selected;
  final bool loading, busy;
  final Widget? feedback;
  final String? feedbackLabel;
  final String? tooltip;
  final FrostButtonEdgeAlignment? edgeAlignment;
  final FocusNode? focusNode;
  final FrostTextRole textRole;
  final bool showsLabel, truncates;
  final FrostButtonGeometry? geometry;
  final FrostButtonPresentation presentation;
  final bool autofocus;
  final bool wrapsLabel;

  @override
  State<FrostButtonControl> createState() => _FrostButtonControlState();
}

class _FrostButtonControlState extends State<FrostButtonControl> {
  static const _iconPop = AlwaysStoppedAnimation<double>(1);
  bool _hovered = false, _pressed = false, _focused = false;
  bool _paddingPressValid = false;
  bool get _interactive => widget.onPressed != null && !widget.loading && !widget.busy;

  @override
  void initState() {
    super.initState();
    FrostInputModality.instance.attach();
    FrostInputModality.instance.addListener(_modalityChanged);
    FocusManager.instance.addHighlightModeListener(_highlightModeChanged);
  }

  void _modalityChanged() {
    if (!mounted) return;
    setState(() {
      if (FrostInputModality.instance.touch) _hovered = false;
    });
  }

  void _highlightModeChanged(FocusHighlightMode _) {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) {
      // This renderer delegates input but owns its fill state. Lifecycle
      // cancellation must reset both owners without firing input callbacks.
      _hovered = false;
      _pressed = false;
      _paddingPressValid = false;
    }
  }

  @override
  void didUpdateWidget(FrostButtonControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_interactive) {
      _pressed = false;
      _paddingPressValid = false;
    }
  }

  @override
  void dispose() {
    FrostInputModality.instance.removeListener(_modalityChanged);
    FrostInputModality.instance.detach();
    FocusManager.instance.removeHighlightModeListener(_highlightModeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final size = widget.size ?? FrostControlScope.sizeOf(context);
    final field = widget.presentation == FrostButtonPresentation.field;
    final invalidField = field && (FrostFieldOptions.of(context)?.invalid ?? false);
    final contentTag = widget.presentation == FrostButtonPresentation.content;
    final height = widget.geometry?.visualHeight ?? size.height(context);
    final density = FrostDensity.of(context);
    final minimumHit = widget.presentation == FrostButtonPresentation.quiet
        ? (density == FrostDensity.comfortable ? FrostControlSize.regular.visualHeight(touch: true) : FrostControlSize.compact.visualHeight(touch: false))
        : density.targetHeight;
    final hit = field ? height : math.min(widget.geometry?.maximumHitHeight ?? double.infinity, math.max(height, math.max(minimumHit, density.targetHeight)));
    final iconSize = widget.geometry?.iconSize ?? size.iconSize;
    final iconOnly = widget.iconStyle != null;
    final mediaInk = FrostOnMediaChromeScope.inkOf(context);
    final iconContent = iconOnly || !widget.showsLabel && (widget.icon != null || widget.iconWidget != null);
    final media = widget.iconStyle == FrostIconButtonStyle.onMedia || mediaInk != null && iconContent;
    final variant = switch (widget.iconStyle) {
      FrostIconButtonStyle.plain => FrostButtonVariant.plain,
      FrostIconButtonStyle.standard => FrostButtonVariant.standard,
      _ => widget.variant,
    };
    final inset = widget.geometry?.horizontalInset ?? frostButtonTextInset(size);
    final disabled = !contentTag && widget.onPressed == null && !widget.loading && !widget.busy;
    final states = <WidgetState>{
      if (!_interactive) WidgetState.disabled,
      if (_hovered) WidgetState.hovered,
      if (_pressed && _interactive) WidgetState.pressed,
      if (_focused) WidgetState.focused,
    };
    final destructive = widget.role == FrostButtonRole.destructive;
    final restingFill = switch ((widget.selected, media, variant)) {
      (true, _, _) => tokens.selectionFill,
      (_, true, _) => tokens.onMediaScrim,
      (_, _, FrostButtonVariant.prominent) =>
        disabled
            ? tokens.fill
            : destructive
            ? tokens.negativeFill
            : tokens.actionFill,
      (_, _, FrostButtonVariant.standard) => mediaInk == null ? tokens.fill : tokens.onMediaScrim,
      _ => (mediaInk == null ? tokens.fillSubtle : tokens.onMediaScrim).withValues(alpha: 0),
    };
    final ink = switch ((widget.selected, media, variant)) {
      (true, _, _) => tokens.selectionInk,
      (_, true, _) => tokens.onMediaInk,
      (_, _, FrostButtonVariant.prominent) when !disabled => destructive ? tokens.onNegative : tokens.onAction,
      _ =>
        destructive
            ? tokens.negativeInk
            : widget.presentation == FrostButtonPresentation.link
            ? tokens.accentInk
            : widget.presentation == FrostButtonPresentation.quiet
            ? mediaInk ?? tokens.textSecondary
            : mediaInk ?? tokens.textPrimary,
    };
    final feedbackRole = variant == FrostButtonVariant.prominent && widget.selected != true ? FrostFeedbackRole.primary : FrostFeedbackRole.quiet;
    var fill = field && frostHasTranslucentWindowBase(context) ? Color.alphaBlend(restingFill, tokens.surface) : restingFill;
    var layer = field
        ? tokens.fillSubtle.withValues(alpha: 0)
        : mediaInk != null && !media && variant != FrostButtonVariant.prominent
        ? mediaInk.withValues(
            alpha: !_interactive
                ? 0
                : _pressed
                ? .08
                : _hovered
                ? .04
                : 0,
          )
        : media || (destructive && feedbackRole == FrostFeedbackRole.primary)
        ? solidWashColor(fill).withValues(
            alpha: !_interactive
                ? 0
                : solidOverlayAlpha(
                    fill,
                    _pressed
                        ? .08
                        : _hovered
                        ? .04
                        : 0,
                  ),
          )
        : frostButtonStateLayer(tokens, states, feedbackRole);
    final actualWindow = FrostWindowBackgroundScope.maybeOf(context)?.background;
    if (actualWindow != null && !field && !media && mediaInk == null && !disabled) {
      final background = FrostSurfaceScope.maybeOf(context)?.background ?? actualWindow;
      fill = frostReadableWindowFill(tokens, Color.alphaBlend(layer, fill), background, ink);
      layer = layer.withValues(alpha: 0);
    }
    final radius = widget.geometry?.cornerRadius ?? FrostRadius.forHeight(height);
    final shape = media ? const CircleBorder() : FrostRadius.shape(context, radius);
    final ringShape = media ? const CircleBorder() : FrostRadius.shape(context, radius + _focusOutset);
    final minimumWidth = iconOnly ? height : widget.geometry?.minimumWidth ?? 0;
    final duration = FrostMotion.duration(context, FrostMotion.hover);

    Widget content = TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: ink),
      duration: duration,
      curve: FrostMotion.hoverCurve,
      builder: (context, foreground, _) => DefaultTextStyle(
        style: FrostTypography.of(context).style(widget.textRole).copyWith(color: foreground),
        child: IconTheme(
          data: IconThemeData(color: foreground, size: iconSize),
          child: FrostLoadingGate(
            loading: widget.loading,
            builder: (context, showLoading) => Stack(
              alignment: Alignment.center,
              fit: StackFit.passthrough,
              children: [
                AnimatedOpacity(
                  opacity: showLoading || widget.feedback != null ? 0 : 1,
                  duration: FrostMotion.duration(context, FrostMotion.layoutFade),
                  child: Row(
                    mainAxisSize: field ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: media ? MainAxisAlignment.center : widget.geometry?.alignment ?? MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null || widget.iconWidget != null)
                        ScaleTransition(
                          scale: _iconPop,
                          child: widget.iconWidget ?? FrostIcon(widget.icon!, size: iconSize, color: field ? tokens.textSecondary : foreground),
                        ),
                      if ((widget.icon != null || widget.iconWidget != null) && widget.showsLabel && !iconOnly)
                        SizedBox(width: widget.geometry?.iconGap ?? (size == FrostControlSize.compact ? _compactIconGap : _regularIconGap)),
                      if (widget.showsLabel && !iconOnly)
                        Flexible(
                          fit: field ? FlexFit.tight : FlexFit.loose,
                          child:
                              widget.labelWidget ??
                              FrostText(
                                widget.label,
                                role: widget.textRole,
                                maxLines: widget.wrapsLabel ? null : 1,
                                overflow: widget.truncates ? TextOverflow.ellipsis : TextOverflow.visible,
                              ),
                        ),
                      if (widget.chevron != FrostButtonChevron.none) ...[
                        const SizedBox(width: _chevronGap),
                        FrostIcon(
                          widget.chevron == FrostButtonChevron.down ? FrostIconSet.of(context).chevronDown : FrostIconSet.of(context).chevronUpDown,
                          size: size.iconSize,
                          color: field ? tokens.textSecondary : foreground,
                        ),
                      ],
                      ?widget.trailing,
                    ],
                  ),
                ),
                if (widget.feedback == null || showLoading)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: showLoading ? 1 : 0,
                        duration: FrostMotion.duration(context, FrostMotion.layoutFade),
                        child: Center(
                          child: TickerMode(
                            enabled: showLoading,
                            child: FrostActivityForeground(
                              color: foreground!,
                              child: FrostActivityIndicator(
                                size: size == FrostControlSize.compact ? FrostControlSize.compact : FrostControlSize.regular,
                                semanticLabel: null,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: FrostMotion.duration(context, FrostMotion.layoutFade),
                        child: showLoading ? const SizedBox.shrink() : widget.feedback ?? const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    content = AnimatedOpacity(opacity: disabled && !FrostControlDimming.ownsOpacityOf(context) ? _disabledOpacity : 1, duration: duration, child: content);
    final visual = CustomPaint(
      foregroundPainter: _interactive && frostShowsFocus(states)
          ? field
                ? FrostFocusOutlinePainter(shape, tokens.focus, FrostMetrics.focusBorderWidth, Directionality.of(context))
                : _ButtonFocusPainter(media ? tokens.onMediaInk : mediaInk ?? tokens.focus, ringShape)
          : null,
      child: FrostClickSurfaceVisuals(
        child: FrostClickSurface(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          onTap: _interactive ? widget.onPressed : null,
          onHover: (value) => setState(() => _hovered = value),
          onPressedChange: (value) => setState(() => _pressed = value && _interactive),
          onFocusChange: (value) => setState(() => _focused = value),
          child: FrostSkeletonShape(
            shape: shape,
            active: fill.a > 0,
            child: FrostInteractionDecoration(
              duration: duration,
              curve: FrostMotion.hoverCurve,
              decoration: ShapeDecoration(shape: shape, color: fill),
              foregroundDecoration: field
                  ? ShapeDecoration(
                      shape: (shape as OutlinedBorder).copyWith(
                        side: BorderSide(
                          color: tokens.negativeInk.withValues(alpha: invalidField ? 1 : 0),
                          width: FrostMetrics.fieldFocusWidth,
                          strokeAlign: BorderSide.strokeAlignInside,
                        ),
                      ),
                    )
                  : null,
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: shape),
                child: FrostInteractionDecoration(
                  duration: duration,
                  curve: FrostMotion.hoverCurve,
                  decoration: ShapeDecoration(shape: shape, color: layer),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height, minWidth: minimumWidth, maxWidth: iconOnly ? height : double.infinity),
                    child: Padding(
                      padding: iconOnly ? EdgeInsets.zero : EdgeInsets.symmetric(horizontal: inset, vertical: widget.geometry?.verticalInset ?? 0),
                      child: content,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Widget control = Listener(
      onPointerDown: (_) => _paddingPressValid = _interactive,
      onPointerCancel: (_) => _paddingPressValid = false,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_paddingPressValid && _interactive) widget.onPressed?.call();
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: hit, minWidth: iconOnly ? hit : 0),
          child: Align(alignment: iconOnly ? Alignment.center : AlignmentDirectional.centerStart, widthFactor: 1, heightFactor: 1, child: visual),
        ),
      ),
    );
    // Ordinary text actions own their full feedback width, including in Wraps.
    // Only an explicit edge alignment or internal geometry may spend keyline
    // room; implicit outsets can overlap a neighbouring control's surface.
    final edgeBleed = widget.geometry?.edgeBleed ?? 0.0;
    final iconInset = (math.max(hit, height) - iconSize) / 2;
    control = FrostButtonInkBounds(
      inset: iconOnly ? iconInset : 0,
      automatic: !media && iconOnly && widget.iconStyle == FrostIconButtonStyle.plain && widget.edgeAlignment == null,
      child: control,
    );
    if (widget.edgeAlignment case final alignment?) {
      control = IntrinsicWidth(
        child: FrostButtonEdgeBleed(
          amount: iconOnly ? iconInset : inset,
          start: alignment == FrostButtonEdgeAlignment.start,
          child: Align(
            alignment: alignment == FrostButtonEdgeAlignment.start ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
            widthFactor: 1,
            heightFactor: 1,
            child: control,
          ),
        ),
      );
    } else if (variant == FrostButtonVariant.plain && edgeBleed > 0) {
      control = IntrinsicWidth(
        child: FrostBleed(
          amount: edgeBleed,
          child: widget.geometry?.edgeBleed == null
              ? control
              : Align(alignment: AlignmentDirectional.centerStart, widthFactor: 1, heightFactor: 1, child: control),
        ),
      );
    }
    final help = widget.tooltip ?? (iconOnly || !widget.showsLabel ? widget.label : null);
    return Semantics(
      button: !contentTag || _interactive,
      label: widget.semanticLabel ?? widget.label,
      hint: widget.tooltip,
      value: widget.feedbackLabel ?? (widget.loading ? FrostScope.labelsOf(context).loading : null),
      liveRegion: widget.loading || widget.feedbackLabel != null,
      toggled: widget.selected,
      selected: contentTag ? widget.selected : null,
      enabled: contentTag && !_interactive ? null : _interactive,
      onTap: _interactive ? widget.onPressed : null,
      excludeSemantics: true,
      child: help == null ? control : FrostTooltip(message: help, excludeFromSemantics: true, child: control),
    );
  }
}

class _ButtonFocusPainter extends CustomPainter {
  const _ButtonFocusPainter(this.color, this.shape);
  final Color color;
  final ShapeBorder shape;

  @override
  void paint(Canvas canvas, Size size) => canvas.drawPath(
    shape.getOuterPath((Offset.zero & size).inflate(_focusOutset)),
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = FrostMetrics.focusBorderWidth,
  );

  @override
  bool shouldRepaint(_ButtonFocusPainter oldDelegate) => color != oldDelegate.color || shape != oldDelegate.shape;
}
