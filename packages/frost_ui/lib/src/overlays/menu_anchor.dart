import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/metrics.dart';
import '../motion/_material_reveal.dart';
import '_anchored_panel_layout.dart';
import '_menu_panel.dart';
import '_menu_target.dart';
import 'menu_entry.dart';
import 'panel_action.dart';

typedef FrostMenuTriggerBuilder = Widget Function(BuildContext context, FocusNode focusNode, VoidCallback toggle);

/// MenuAnchor whose trigger takes focus when it opens the menu. A pointer
/// click does not focus a button, and without focus in the anchor Escape and
/// the arrow keys never reach the open menu. Closing returns focus to the
/// trigger, which is already where it is.
class FrostMenuAnchor extends StatelessWidget {
  const FrostMenuAnchor({required this.entries, required this.builder, this.alignmentOffset, super.key});
  final List<FrostMenuEntry> entries;
  final FrostMenuTriggerBuilder builder;
  final Offset? alignmentOffset;
  @override
  Widget build(BuildContext context) => FrostMenuHost(entries: entries, builder: builder, alignmentOffset: alignmentOffset);
}

/// Internal host shared by anchored controls and point-anchored context menus.
class FrostMenuHost extends StatefulWidget {
  const FrostMenuHost({
    required this.entries,
    required this.builder,
    this.alignmentOffset,
    this.autoOpen = false,
    this.onClosed,
    this.returnFocus,
    this.panelBuilder,
    super.key,
  });

  final List<FrostMenuEntry> entries;
  final bool autoOpen;
  final VoidCallback? onClosed;
  final FocusNode? returnFocus;
  final FrostMenuTriggerBuilder builder;
  final Offset? alignmentOffset;
  // Arbitrary content remains a library-only host capability. Public menus
  // accept entries; FrostPopover is the public arbitrary-content component.
  final Widget Function(BuildContext context, VoidCallback close)? panelBuilder;

  @override
  State<FrostMenuHost> createState() => _AppMenuAnchorState();
}

class _AppMenuAnchorState extends State<FrostMenuHost> with SingleTickerProviderStateMixin {
  final _controller = MenuController();
  final _focusNode = FocusNode(debugLabel: 'Menu trigger');
  final _menuFocus = FocusScopeNode(debugLabel: 'Menu');

  /// 0 closed, 1 open; a spring, so reopening mid-close turns back smoothly.
  late final AnimationController _reveal = AnimationController.unbounded(vsync: this);
  final _glass = FrostRevealHandle();
  bool _closing = false;
  LocalHistoryEntry? _history;
  Completer<void>? _closed;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusChanged);
    _menuFocus.addListener(_focusChanged);
    if (widget.autoOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggle();
      });
    }
  }

  @override
  void dispose() {
    _closing = true;
    if (_closed?.isCompleted == false) _closed!.complete();
    _history?.remove();
    _history = null;
    _reveal.dispose();
    _menuFocus.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (_closing || !mounted) return;
    if (!_focusNode.hasFocus && !_menuFocus.hasFocus && _controller.isOpen) _controller.close();
  }

  bool get _tickersEnabled => TickerMode.valuesOf(context).enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A subtree whose tickers stop (a collapsing download panel) cannot run
    // the closing spring; its open menu closes at once instead of freezing
    // half-shrunk on screen.
    if (!_tickersEnabled && _controller.isOpen) _controller.close();
  }

  void _toggle() {
    if (widget.entries.isEmpty && widget.panelBuilder == null) return;
    if (_controller.isOpen && !_closing) {
      _controller.close();
      return;
    }
    _focusNode.requestFocus();
    _controller.open();
  }

  @override
  Widget build(BuildContext context) {
    // The menu grows out of its anchor on a spring and shrinks back into it,
    // on the glass overlay material; the framework's
    // own menu animation has fixed Material timings.
    // Local history handles imperative Navigator.pop. PopScope also publishes
    // Android's frameworkHandlesBack policy; local history does not notify that
    // policy when added to a root route on its own.
    return PopScope<Object?>(
      canPop: _history == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _controller.isOpen && !_closing) _controller.close();
      },
      child: RawMenuAnchor(
        controller: _controller,
        childFocusNode: _focusNode,
        onClose: () {
          widget.onClosed?.call();
          if (_closed?.isCompleted == false) _closed!.complete();
        },
        onOpenRequested: (position, showOverlay) {
          _closed = Completer<void>();
          _closing = false;
          final route = ModalRoute.of(context);
          if (_history == null && route != null) {
            // RawMenuAnchor is an Overlay, not a route. Local history lets system
            // Back close it before a root/nested page and disables page preview
            // while the menu owns that return, using the framework's usual path.
            _history = LocalHistoryEntry(
              impliesAppBarDismissal: false,
              onRemove: () {
                _history = null;
                if (mounted && !_closing && _controller.isOpen) _controller.close();
              },
            );
            route.addLocalHistoryEntry(_history!);
            setState(() {});
          }
          _glass.cancelClose();
          showOverlay();
          _animateReveal(true);
          if (widget.panelBuilder != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _closing || !_controller.isOpen) return;
              final nodes = _menuFocus.traversalDescendants.where((node) => node.canRequestFocus && !node.skipTraversal);
              if (nodes.isNotEmpty) {
                nodes.first.requestFocus();
              } else {
                _menuFocus.requestFocus();
              }
            });
          }
        },
        onCloseRequested: (hideOverlay) {
          final ownsFocus = _focusNode.hasFocus || _menuFocus.hasFocus;
          _closing = true;
          final history = _history;
          _history = null;
          history?.remove();
          setState(() {});
          if (ownsFocus) {
            final target = widget.returnFocus ?? _focusNode;
            if (target.context != null && target.canRequestFocus) target.requestFocus();
          }
          if (!_tickersEnabled) {
            _closing = false;
            _reveal.value = 0;
            hideOverlay();
            return;
          }
          _closing = true;
          _glass.prepareClose().then((ready) {
            if (!ready || !mounted || !_closing) return;
            _animateReveal(false).orCancel.then((_) {
              if (mounted && _closing) {
                _closing = false;
                hideOverlay();
              }
            }, onError: (_) {});
          });
        },
        overlayBuilder: (overlayContext, info) => FrostPanelActionScope(
          origin: context,
          close: () async {
            if (!_controller.isOpen) return false;
            final done = _closed!.future;
            _controller.close();
            await done;
            return true;
          },
          child: _AnchoredMenu(
            info: RawMenuOverlayInfo(
              anchorRect: FrostMenuTarget.rectOf(context) ?? info.anchorRect,
              overlaySize: info.overlaySize,
              tapRegionGroupId: info.tapRegionGroupId,
              position: info.position,
            ),
            offset: widget.alignmentOffset ?? frostAnchoredPanelGap,
            reveal: _reveal,
            revealHandle: _glass,
            closing: () => _closing,
            focusNode: _menuFocus,
            onDismiss: _controller.close,
            entries: widget.entries,
            triggerWidth: FrostMenuTarget.matchesWidthOf(context) ? (FrostMenuTarget.rectOf(context) ?? info.anchorRect).width : null,
            panelBuilder: widget.panelBuilder,
          ),
        ),
        builder: (context, controller, _) => widget.builder(context, _focusNode, _toggle),
      ),
    );
  }

  TickerFuture _animateReveal(bool opening) {
    if (widget.panelBuilder != null && MediaQuery.disableAnimationsOf(context)) {
      return _reveal.animateTo(opening ? 1 : 0, duration: FrostMotion.reducedFade, curve: opening ? Curves.easeOutCubic : Curves.easeInCubic);
    }
    return FrostMotion.springTo(context, _reveal, opening ? 1 : 0, opening ? FrostMotion.standard : FrostMotion.snappy);
  }
}

/// Lets the items of an open [FrostMenuAnchor] close it.
class FrostMenuScope extends InheritedWidget {
  const FrostMenuScope({required this.close, required super.child, super.key});

  final VoidCallback close;

  @override
  bool updateShouldNotify(FrostMenuScope oldWidget) => close != oldWidget.close;
}

/// The open menu of an [FrostMenuAnchor]: below the anchor (above when there is
/// no room), kept inside the overlay, as a glass panel that scales in from
/// the anchor's side.
class _AnchoredMenu extends StatelessWidget {
  const _AnchoredMenu({
    required this.info,
    required this.offset,
    required this.reveal,
    required this.revealHandle,
    required this.closing,
    required this.focusNode,
    required this.onDismiss,
    required this.entries,
    required this.triggerWidth,
    required this.panelBuilder,
  });

  final RawMenuOverlayInfo info;
  final Offset offset;
  final Animation<double> reveal;
  final FrostRevealHandle revealHandle;
  final bool Function() closing;
  final FocusScopeNode focusNode;
  final VoidCallback onDismiss;
  final List<FrostMenuEntry> entries;
  final double? triggerWidth;
  final Widget Function(BuildContext context, VoidCallback close)? panelBuilder;

  @override
  Widget build(BuildContext context) {
    final anchor = info.anchorRect;
    final room = info.overlaySize;
    final below = room.height - anchor.bottom >= anchor.top || room.height - anchor.bottom >= 240;
    return CustomSingleChildLayout(
      delegate: FrostAnchoredPanelLayout(anchor: anchor, offset: offset, below: below, margin: frostAnchoredPanelMargin),
      child: TapRegion(
        groupId: info.tapRegionGroupId,
        onTapOutside: (_) => onDismiss(),
        child: FocusScope(
          node: focusNode,
          child: Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
              SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
              SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),
            },
            child: Actions(
              actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => onDismiss())},
              child: FrostMenuScope(
                close: onDismiss,
                child: FrostMenuReveal(
                  reveal: reveal,
                  handle: revealHandle,
                  closing: closing,
                  alignment: below ? AlignmentDirectional.topStart : AlignmentDirectional.bottomStart,
                  child: panelBuilder?.call(context, onDismiss) ?? FrostMenuPanel(triggerWidth: triggerWidth, children: frostMenuChildren(context, entries)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scales a menu panel in from its anchor side (0.94 → 1) and fades it, with
/// [reveal] running 0 → 1. While [closing] it no longer takes input.
class FrostMenuReveal extends StatelessWidget {
  const FrostMenuReveal({required this.reveal, required this.closing, required this.alignment, required this.child, this.handle, super.key});

  final FrostRevealHandle? handle;
  final Animation<double> reveal;
  final bool Function() closing;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, child) {
        final progress = reveal.value.clamp(0.0, 1.0);
        final shut = closing();
        return IgnorePointer(
          ignoring: shut,
          child: ExcludeFocus(
            excluding: shut,
            child: ExcludeSemantics(
              excluding: shut,
              child: FrostMaterialReveal(
                handle: handle,
                opacity: progress,
                child: Transform.scale(
                  scale: MediaQuery.disableAnimationsOf(context) ? 1 : .94 + .06 * progress,
                  alignment: alignment.resolve(Directionality.of(context)),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
