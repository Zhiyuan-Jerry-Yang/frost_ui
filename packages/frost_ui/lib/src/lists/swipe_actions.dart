import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../feedback/_skeleton_geometry.dart';
import '../foundation/_focus_modality.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../overlays/_additional_menu_entries.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/presence.dart';

/// Action widths stay tappable even with a short localized label.
const _swipeMinimumWidth = 72.0;
const _swipeHorizontalInset = 12.0;
// Full swipe acts on release; ordinary opening uses half the action extent.
const _swipeTriggerFraction = .6;
const _swipeOpenFraction = .5;
// Matches the media viewport's directional release velocity.
const _swipeReleaseVelocity = 700.0;

enum FrostSwipeTone { normal, accent, destructive }

@immutable
class FrostSwipeAction {
  const FrostSwipeAction({required this.label, required this.icon, required this.onPressed, this.tone = FrostSwipeTone.normal});
  final String label;
  final FrostIconData icon;
  final VoidCallback onPressed;
  final FrostSwipeTone tone;
}

/// Touch actions follow the finger; a mouse instead reveals the same actions
/// as compact buttons and a context menu. Only one row per Flutter view stays
/// open. Leading/trailing always follow the current text direction.
class FrostSwipeActions extends StatefulWidget {
  const FrostSwipeActions({required this.child, this.leading = const [], this.trailing = const [], this.showsPointerActions = true, super.key});
  final Widget child;
  final List<FrostSwipeAction> leading, trailing;

  /// Whether to generate mouse-hover buttons from [leading] and [trailing].
  ///
  /// Disable this when the row supplies its own pointer controls. Touch swipes,
  /// context-menu actions and their keyboard access remain available.
  final bool showsPointerActions;
  @override
  State<FrostSwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<FrostSwipeActions> with SingleTickerProviderStateMixin {
  static final _openRows = Expando<_SwipeActionsState>();
  late final _offset = AnimationController.unbounded(vsync: this);
  Object? _view;
  bool _hovered = false, _dragging = false;
  bool _holdingPointerActions = false;
  bool _enabled = true;
  double _width = 0, _leadingExtent = 0, _trailingExtent = 0;
  double get _direction => Directionality.of(context) == TextDirection.rtl ? -1 : 1;
  List<FrostSwipeAction> get _actions => [...widget.leading, ...widget.trailing];

  @override
  void initState() {
    super.initState();
    FrostInputModality.instance.attach();
    FrostInputModality.instance.addListener(_modalityChanged);
  }

  void _modalityChanged() {
    if (mounted && _hovered && FrostInputModality.instance.touch) setState(() => _hovered = false);
  }

  void _updateHover(PointerEvent event) {
    if (event.kind == PointerDeviceKind.mouse && FrostInputModality.instance.acceptsHover(event) && !_hovered) setState(() => _hovered = true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = FrostControlScope.enabledOf(context);
    if (_enabled && !enabled) {
      _dragging = false;
      _close();
    }
    _enabled = enabled;
    final view = View.of(context);
    if (!identical(view, _view)) {
      if (_view != null && identical(_openRows[_view!], this)) _openRows[_view!] = null;
      _view = view;
      _offset.value = 0;
    }
  }

  @override
  void didUpdateWidget(FrostSwipeActions oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_offset.value > 0 && widget.leading.isEmpty || _offset.value < 0 && widget.trailing.isEmpty) {
      _dragging = false;
      _close();
    }
  }

  void _claim() {
    final previous = _openRows[_view!];
    if (previous != null && previous != this && previous.mounted) previous._close();
    _openRows[_view!] = this;
  }

  void _close() {
    if (_view != null && identical(_openRows[_view!], this)) _openRows[_view!] = null;
    FrostMotion.springTo(context, _offset, 0, FrostMotion.snappy);
  }

  void _start(DragStartDetails details) {
    _claim();
    _dragging = true;
    _offset.stop();
  }

  void _update(DragUpdateDetails details) {
    if (!_dragging || !_enabled) return;
    final next = _offset.value + details.delta.dx * _direction;
    _offset.value = next.clamp(widget.trailing.isEmpty ? 0 : -_width, widget.leading.isEmpty ? 0 : _width);
  }

  void _end(DragEndDetails details) {
    if (!_dragging || !_enabled) return;
    _dragging = false;
    final value = _offset.value;
    final leading = value >= 0;
    final actions = leading ? widget.leading : widget.trailing;
    final extent = leading ? _leadingExtent : _trailingExtent;
    if (actions.isEmpty) {
      _close();
      return;
    }
    if (value.abs() >= _width * _swipeTriggerFraction) {
      _close();
      actions.first.onPressed();
      return;
    }
    final outwardVelocity = details.velocity.pixelsPerSecond.dx * _direction * (leading ? 1 : -1);
    final open = outwardVelocity.abs() > _swipeReleaseVelocity ? outwardVelocity > 0 : value.abs() >= extent * _swipeOpenFraction;
    if (!open) {
      _close();
      return;
    }
    _claim();
    FrostMotion.springTo(context, _offset, (leading ? 1 : -1) * math.min(extent, _width), FrostMotion.snappy);
  }

  void _invoke(FrostSwipeAction action) {
    _dragging = false;
    _close();
    action.onPressed();
  }

  double _actionWidth(FrostSwipeAction action, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: action.label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = math.max(_swipeMinimumWidth, math.max(painter.width, FrostControlSize.compact.iconSize) + _swipeHorizontalInset * 2);
    painter.dispose();
    return width;
  }

  @override
  void dispose() {
    FrostInputModality.instance.removeListener(_modalityChanged);
    FrostInputModality.instance.detach();
    if (_view != null && identical(_openRows[_view!], this)) _openRows[_view!] = null;
    _offset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actions = _actions;
    final menu = [
      for (final action in actions)
        FrostMenuAction(action.label, icon: action.icon, destructive: action.tone == FrostSwipeTone.destructive, onSelected: () => _invoke(action)),
    ];
    final style = FrostTypography.of(context).style(FrostTextRole.callout);
    final leadingWidths = [for (final action in widget.leading) _actionWidth(action, style)];
    final trailingWidths = [for (final action in widget.trailing) _actionWidth(action, style)];
    final painter = TextPainter(
      text: TextSpan(style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final actionHeight = math.max(FrostDensity.of(context).targetHeight, painter.preferredLineHeight + FrostControlSize.compact.iconSize + FrostGap.inline);
    painter.dispose();
    _leadingExtent = leadingWidths.fold(0.0, (sum, width) => sum + width);
    _trailingExtent = trailingWidths.fold(0.0, (sum, width) => sum + width);
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        final buttons = [
          for (final action in widget.showsPointerActions ? actions : const <FrostSwipeAction>[])
            FrostButton.icon(
              label: action.label,
              icon: action.icon,
              size: FrostControlSize.compact,
              role: action.tone == FrostSwipeTone.destructive ? FrostButtonRole.destructive : FrostButtonRole.normal,
              onPressed: () => _invoke(action),
            ),
        ];
        final hover = FrostPresence(
          visible: (_hovered || _holdingPointerActions) && buttons.isNotEmpty,
          effect: FrostPresenceEffect.expand,
          axis: Axis.horizontal,
          child: Wrap(alignment: WrapAlignment.end, children: buttons),
        );
        final controlsWidth = FrostDensity.of(context).targetHeight * buttons.length;
        final foreground = !widget.showsPointerActions
            ? widget.child
            : controlsWidth <= constraints.maxWidth
            ? Row(
                children: [
                  Expanded(child: widget.child),
                  hover,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  widget.child,
                  Align(alignment: AlignmentDirectional.centerEnd, child: hover),
                ],
              );
        return GestureDetector(
          supportedDevices: const {PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus},
          onHorizontalDragStart: actions.isEmpty || !_enabled ? null : _start,
          onHorizontalDragUpdate: actions.isEmpty || !_enabled ? null : _update,
          onHorizontalDragEnd: actions.isEmpty || !_enabled ? null : _end,
          onHorizontalDragCancel: () {
            _dragging = false;
            _close();
          },
          child: AnimatedBuilder(
            animation: _offset,
            // The child's click surface owns both hover and press, including
            // its group corners and granted keyline bleed. Pointer actions are
            // independent controls; an outer hover-only layer disagrees with it.
            child: foreground,
            builder: (context, child) => ClipRect(
              // Clip the translated swipe only. At rest the shared row's
              // granted keyline bleed includes complete button ink and hits.
              clipBehavior: _dragging || _offset.value != 0 ? Clip.hardEdge : Clip.none,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: _actionGroup(widget.leading, leadingWidths, leading: true)),
                  Positioned.fill(child: _actionGroup(widget.trailing, trailingWidths, leading: false)),
                  Transform.translate(
                    offset: Offset(_offset.value * _direction, 0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: actions.isEmpty || (!_dragging && _offset.value == 0) ? 0 : actionHeight),
                      child: ColoredBox(
                        color: _offset.value == 0
                            ? FrostThemeTokens.of(context).surface.withValues(alpha: 0)
                            : (FrostKeyline.maybeOf(context)?.insideContainer == true
                                  ? FrostThemeTokens.of(context).surface
                                  : FrostThemeTokens.of(context).canvas),
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    content = MouseRegion(
      onEnter: _updateHover,
      onHover: _updateHover,
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        // Keep a visible pointer action alive when a touch activates it, through
        // release, without retaining the row's previous mouse hover feedback.
        onPointerDown: (_) => setState(() => _holdingPointerActions = _hovered),
        onPointerUp: (_) => setState(() => _holdingPointerActions = false),
        onPointerCancel: (_) => setState(() => _holdingPointerActions = false),
        child: content,
      ),
    );
    return FrostAdditionalMenuEntries(
      entries: menu,
      child: FrostContextMenuRegion(entries: menu, child: content),
    );
  }

  Widget _actionGroup(List<FrostSwipeAction> actions, List<double> widths, {required bool leading}) {
    if (leading ? _offset.value <= 0 : _offset.value >= 0) return const SizedBox.shrink();
    final tokens = FrostThemeTokens.of(context);
    final extent = leading ? _leadingExtent : _trailingExtent;
    return Align(
      alignment: leading ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: IgnorePointer(
        ignoring: leading ? _offset.value <= 0 : _offset.value >= 0,
        child: ExcludeSemantics(
          excluding: leading ? _offset.value <= 0 : _offset.value >= 0,
          child: SizedBox(
            width: math.min(extent, _width),
            height: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              reverse: !leading,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < actions.length; i++)
                    SizedBox(
                      width: widths[i],
                      child: ColoredBox(
                        color: switch (actions[i].tone) {
                          FrostSwipeTone.normal => tokens.fillStrong,
                          FrostSwipeTone.accent => tokens.actionFill,
                          FrostSwipeTone.destructive => tokens.negativeFill,
                        },
                        child: FrostClickSurface(
                          onTap: () => _invoke(actions[i]),
                          borderRadius: BorderRadius.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: _swipeHorizontalInset),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FrostIcon(
                                  actions[i].icon,
                                  size: FrostControlSize.compact.iconSize,
                                  color: actions[i].tone == FrostSwipeTone.normal ? tokens.textPrimary : tokens.onAction,
                                ),
                                const SizedBox(height: FrostGap.inline),
                                FrostSkeletonText(
                                  child: Text(
                                    actions[i].label,
                                    textAlign: TextAlign.center,
                                    style: FrostTypography.of(context)
                                        .style(FrostTextRole.callout)
                                        .copyWith(color: actions[i].tone == FrostSwipeTone.normal ? tokens.textPrimary : tokens.onAction),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
