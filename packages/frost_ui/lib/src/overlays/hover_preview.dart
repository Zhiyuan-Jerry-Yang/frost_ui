import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show DialogTheme;
import 'package:flutter/services.dart' show KeyDownEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/tokens.dart';
import '../motion/_material_reveal.dart';
import '_anchored_panel_layout.dart';
import '_popover_surface.dart';
import 'menu_anchor.dart' show FrostMenuReveal;

// Preview timing allows moving from the trigger into the card without flicker.
const _previewDelay = Duration(milliseconds: 600);
const _previewExitGrace = Duration(milliseconds: 150);
const _previewMaximumWidth = 320.0;

/// Passive preview content using Popover material. Focus remains on the trigger.
/// Desktop input outside the card passes through. Touch long press shows a
/// centered, masked preview until release; avoid competing child long presses.
class FrostHoverPreview extends StatefulWidget {
  const FrostHoverPreview({required this.child, required this.previewBuilder, this.enabled = true, super.key});
  final Widget child;
  final WidgetBuilder previewBuilder;
  final bool enabled;
  @override
  State<FrostHoverPreview> createState() => _HoverPreviewState();
}

class _HoverPreviewState extends State<FrostHoverPreview> with SingleTickerProviderStateMixin {
  final _portal = OverlayPortalController();
  final _tapGroup = Object();
  static final _openedPreviews = <_HoverPreviewState>{};
  late final _reveal = AnimationController.unbounded(vsync: this);
  final _glass = FrostRevealHandle();
  Timer? _delay, _exit;
  bool _hover = false, _cardHover = false, _focused = false;
  bool _shown = false, _present = false, _touch = false;
  bool get _active => _hover || _cardHover || _focused;
  @override
  void initState() {
    super.initState();
    _portal.show();
    GestureBinding.instance.pointerRouter.addGlobalRoute(_handlePointer);
  }

  @override
  void didUpdateWidget(FrostHoverPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled && _active) _scheduleOpen();
    if (!widget.enabled) {
      _delay?.cancel();
      _exit?.cancel();
      if (_present) _close(rebuild: false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) {
      _delay?.cancel();
      _exit?.cancel();
      _openedPreviews.remove(this);
      _shown = false;
      _present = false;
    }
  }

  // Like Tooltip, pointer input dismisses the preview without knowing which
  // menu, route or focus action receives that input. Scroll remains unconsumed.
  void _handlePointer(PointerEvent event) {
    if (event is PointerDownEvent || event is PointerScrollEvent || event is PointerPanZoomStartEvent) {
      _delay?.cancel();
      if (_shown) _close();
    }
  }

  void _scheduleOpen() {
    _exit?.cancel();
    if (!widget.enabled || _shown || _delay?.isActive == true) return;
    _delay = Timer(_previewDelay, () {
      if (mounted && _active) _open(touch: false);
    });
  }

  void _scheduleClose() {
    _delay?.cancel();
    if (_active || !_shown) return;
    _exit?.cancel();
    _exit = Timer(_previewExitGrace, () {
      if (mounted && !_active) _close();
    });
  }

  TickerFuture _animate(bool opening) {
    if (MediaQuery.disableAnimationsOf(context)) return _reveal.animateTo(opening ? 1 : 0, duration: FrostMotion.reducedFade);
    return FrostMotion.springTo(context, _reveal, opening ? 1 : 0, opening ? FrostMotion.standard : FrostMotion.snappy);
  }

  void _open({required bool touch}) {
    if (!mounted || !widget.enabled || !TickerMode.valuesOf(context).enabled) return;
    _delay?.cancel();
    _exit?.cancel();
    for (final preview in _openedPreviews.toList()) {
      if (!identical(preview, this)) preview._close();
    }
    _openedPreviews.add(this);
    setState(() {
      _touch = touch;
      _shown = true;
      _present = true;
    });
    _glass.cancelClose();
    _animate(true);
  }

  void _close({bool rebuild = true}) {
    _delay?.cancel();
    _exit?.cancel();
    _openedPreviews.remove(this);
    if (!_present || !_shown) return;
    if (rebuild) {
      setState(() => _shown = false);
    } else {
      _shown = false;
    }
    _glass.prepareClose().then((ready) {
      if (!ready || !mounted || _shown) return;
      _animate(false).orCancel.then((_) {
        if (mounted && !_shown) setState(() => _present = false);
      }, onError: (_) {});
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _exit?.cancel();
    _openedPreviews.remove(this);
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handlePointer);
    _reveal.dispose();
    super.dispose();
  }

  Widget _overlay(BuildContext context, OverlayChildLayoutInfo info) {
    if (!_present) return const SizedBox.shrink();
    final media = MediaQuery.of(this.context);
    final insets = EdgeInsets.fromLTRB(media.padding.left, media.padding.top, media.padding.right, math.max(media.padding.bottom, media.viewInsets.bottom));
    final anchor = MatrixUtils.transformRect(info.childPaintTransform, Offset.zero & info.childSize);
    final panel = TapRegion(
      groupId: _tapGroup,
      onTapOutside: (_) => _close(),
      child: MouseRegion(
        onEnter: (_) {
          _cardHover = true;
          _exit?.cancel();
        },
        onExit: (_) {
          _cardHover = false;
          _scheduleClose();
        },
        child: ExcludeFocus(
          child: FrostMenuReveal(
            reveal: _reveal,
            handle: _glass,
            closing: () => !_shown,
            alignment: _touch ? Alignment.center : AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _previewMaximumWidth),
              child: FrostPopoverSurface(
                child: SingleChildScrollView(primary: false, child: Builder(builder: widget.previewBuilder)),
              ),
            ),
          ),
        ),
      ),
    );
    return MediaQuery(
      data: media,
      child: Stack(
        children: [
          if (_touch)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _reveal,
                builder: (context, _) => Opacity(
                  opacity: _reveal.value.clamp(0.0, 1.0),
                  child: AbsorbPointer(child: ColoredBox(color: DialogTheme.of(context).barrierColor ?? FrostThemeTokens.of(context).onMediaScrim)),
                ),
              ),
            ),
          Positioned.fill(
            child: CustomSingleChildLayout(
              delegate: _touch
                  ? _CenteredPreviewLayout(insets)
                  : FrostAnchoredPanelLayout(anchor: anchor, offset: frostAnchoredPanelGap, below: true, margin: frostAnchoredPanelMargin, insets: insets),
              child: panel,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape && _shown) {
        _close();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
    skipTraversal: true,
    onFocusChange: (focused) {
      _focused = focused;
      if (focused) {
        _scheduleOpen();
      } else {
        _scheduleClose();
      }
    },
    child: MouseRegion(
      onEnter: (_) {
        _hover = true;
        _scheduleOpen();
      },
      onExit: (_) {
        _hover = false;
        _scheduleClose();
      },
      child: GestureDetector(
        supportedDevices: const {PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus},
        onLongPressStart: widget.enabled ? (_) => _open(touch: true) : null,
        onLongPressEnd: widget.enabled ? (_) => _close() : null,
        onLongPressCancel: widget.enabled ? _close : null,
        child: TapRegion(
          groupId: _tapGroup,
          child: OverlayPortal.overlayChildLayoutBuilder(controller: _portal, overlayChildBuilder: _overlay, child: widget.child),
        ),
      ),
    ),
  );
}

class _CenteredPreviewLayout extends SingleChildLayoutDelegate {
  const _CenteredPreviewLayout(this.insets);
  final EdgeInsets insets;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) => BoxConstraints(
    maxWidth: math.max(0, constraints.maxWidth - insets.horizontal - frostAnchoredPanelMargin * 2),
    maxHeight: math.max(0, constraints.maxHeight - insets.vertical - frostAnchoredPanelMargin * 2),
  );
  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      Offset(insets.left + (size.width - insets.horizontal - childSize.width) / 2, insets.top + (size.height - insets.vertical - childSize.height) / 2);
  @override
  bool shouldRelayout(_CenteredPreviewLayout oldDelegate) => insets != oldDelegate.insets;
}

extension FrostHoverPreviewX on Widget {
  Widget frostHoverPreview(WidgetBuilder previewBuilder, {bool enabled = true}) =>
      FrostHoverPreview(previewBuilder: previewBuilder, enabled: enabled, child: this);
}
