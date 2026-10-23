import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../controls/buttons.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../media/_pager_media_scope.dart';
import '../primitives/presence.dart';
import 'page_indicator.dart';

// Media controls share one edge inset; the indicator capsule uses its own padding.
const _mediaControlInset = 12.0;
const _indicatorHorizontalPadding = 8.0;
const _indicatorVerticalPadding = 6.0;
const _indicatorBelowGap = 8.0;

enum FrostPageIndicatorPlacement { below, overlay }

/// Controls one pager. Unbound requests are remembered until attachment.
///
/// A supplied controller takes precedence over FrostPager.initialPage. Empty
/// pagers clamp to page zero. Dispose this controller after detaching its pager.
class FrostPagerController extends ChangeNotifier {
  int _page = 0;
  int get page => _page;
  _FrostPagerState? _owner;
  bool _disposed = false, _notificationPending = false;

  void jumpTo(int page) {
    assert(!_disposed);
    if (_owner case final owner?) {
      unawaited(owner._move(page, animate: false));
    } else {
      _publish(page < 0 ? 0 : page);
    }
  }

  Future<void> animateTo(int page) {
    assert(!_disposed);
    if (_owner case final owner?) return owner._move(page, animate: true);
    _publish(page < 0 ? 0 : page);
    return Future.value();
  }

  void _attach(_FrostPagerState owner) {
    assert(_owner == null || _owner == owner, 'A FrostPagerController can bind only one pager.');
    _owner = owner;
  }

  void _detach(_FrostPagerState owner) {
    if (_owner == owner) _owner = null;
  }

  void _publish(int page, {bool defer = false}) {
    if (_page == page || _disposed) return;
    _page = page;
    if (!defer) {
      notifyListeners();
      return;
    }
    if (_notificationPending) return;
    _notificationPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationPending = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _owner = null;
    super.dispose();
  }
}

/// Lazy horizontal pages in a finite-height slot, with one keyboard stop.
///
/// Descendant focus handlers take priority, so a thumbnail strip or editable
/// field keeps its own navigation. Dragging interrupts programmatic motion.
/// Reduced motion jumps directly to the requested page.
class FrostPager extends StatefulWidget {
  const FrostPager({
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.initialPage = 0,
    this.onPageChanged,
    this.showsIndicator = true,
    this.indicatorPlacement = FrostPageIndicatorPlacement.below,
    super.key,
  }) : assert(itemCount >= 0),
       assert(initialPage >= 0);
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final FrostPagerController? controller;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;
  final bool showsIndicator;
  final FrostPageIndicatorPlacement indicatorPlacement;
  @override
  State<FrostPager> createState() => _FrostPagerState();
}

class _FrostPagerState extends State<FrostPager> with SingleTickerProviderStateMixin {
  late final _owned = FrostPagerController().._page = widget.initialPage;
  FrostPagerController get _controller => widget.controller ?? _owned;
  late int _page = _clamp(_controller.page);
  late int _target = _page;
  late PageController _pages = PageController(initialPage: _page, keepPage: false);
  late final _motion = AnimationController.unbounded(vsync: this, value: _page.toDouble())..addListener(_tick);
  final _focus = FocusNode();
  final _zoomedMedia = <Object, int>{};
  bool _hovered = false, _showsFocus = false;
  int _request = 0, _change = 0;

  int _clamp(int page) => widget.itemCount == 0 ? 0 : page.clamp(0, widget.itemCount - 1);
  @override
  void initState() {
    super.initState();
    _controller._attach(this);
    _controller._publish(_page, defer: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && _motion.isAnimating) {
      final previous = _page;
      _page = _target;
      _replacePages();
      _controller._publish(_page, defer: true);
      if (previous != _page) _notifyChanged(_page, defer: true);
    }
  }

  void _replacePages() {
    _request++;
    _motion.stop();
    final old = _pages;
    _pages = PageController(initialPage: _page, keepPage: false);
    _motion.value = _page.toDouble();
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void didUpdateWidget(FrostPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = _page;
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _owned)._detach(this);
      _controller._attach(this);
      _page = _target = _clamp(_controller.page);
      _replacePages();
    } else if (_page != _clamp(_page) || (oldWidget.itemCount == 0) != (widget.itemCount == 0)) {
      _page = _target = _clamp(_page);
      _replacePages();
    } else if (_target != _clamp(_target)) {
      _target = _clamp(_target);
      _request++;
      _motion.stop();
      final target = _target;
      final request = _request;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && request == _request) unawaited(_move(target, animate: true));
      });
    }
    _controller._publish(_page, defer: true);
    if (previous != _page) _notifyChanged(_page, defer: true);
  }

  void _tick() {
    if (!_pages.hasClients || !_pages.position.hasContentDimensions) return;
    final position = _pages.position;
    _pages.jumpTo((_motion.value * position.viewportDimension).clamp(position.minScrollExtent, position.maxScrollExtent));
  }

  Future<void> _move(int page, {required bool animate}) async {
    final target = _clamp(page);
    _target = target;
    final request = ++_request;
    if (widget.itemCount == 0) return;
    if (!_pages.hasClients || !_pages.position.hasContentDimensions) {
      final ready = Completer<void>();
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          if (mounted && request == _request) await _move(target, animate: animate);
          ready.complete();
        } catch (error, stack) {
          ready.completeError(error, stack);
        }
      });
      return ready.future;
    }
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      _motion.stop();
      _motion.value = target.toDouble();
      _pages.jumpToPage(target);
      return;
    }
    if (!_motion.isAnimating) _motion.value = _pages.page ?? _page.toDouble();
    try {
      await FrostMotion.springTo(context, _motion, target.toDouble(), FrostMotion.standard).orCancel;
    } on TickerCanceled {
      // Interruption completes this request; the new gesture/request owns motion.
    }
  }

  void _changed(int page) {
    if (_page == page) return;
    setState(() => _page = page);
    if (!_motion.isAnimating) _target = page;
    _controller._publish(page, defer: SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks);
    _notifyChanged(page, defer: SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks);
  }

  void _notifyChanged(int page, {required bool defer}) {
    final change = ++_change;
    if (!defer) {
      widget.onPageChanged?.call(page);
      return;
    }
    // Lifecycle/layout corrections paint the final page in the same frame;
    // their outward notification must not rebuild a caller during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && change == _change && page == _page) widget.onPageChanged?.call(page);
    });
  }

  void _zoom(Object source, int index, bool zoomed) {
    if (!mounted) return;
    final before = _zoomedMedia.containsValue(_page);
    if (zoomed) {
      _zoomedMedia[source] = index;
    } else {
      _zoomedMedia.remove(source);
    }
    if (before != _zoomedMedia.containsValue(_page)) setState(() {});
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (widget.itemCount == 0 || (event is! KeyDownEvent && event is! KeyRepeatEvent)) return KeyEventResult.ignored;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final next = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => _target + (rtl ? 1 : -1),
      LogicalKeyboardKey.arrowRight => _target + (rtl ? -1 : 1),
      LogicalKeyboardKey.pageUp => _target - 1,
      LogicalKeyboardKey.pageDown => _target + 1,
      LogicalKeyboardKey.home => 0,
      LogicalKeyboardKey.end => widget.itemCount - 1,
      _ => null,
    };
    if (next == null) return KeyEventResult.ignored;
    unawaited(_move(next, animate: true));
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _request++;
    _controller._detach(this);
    _owned.dispose();
    _motion.dispose();
    _pages.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pointer = switch (Theme.of(context).platform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };
    final labels = FrostScope.labelsOf(context);
    final icons = FrostIconSet.of(context);
    Widget arrow({required bool previous}) => FrostPresence(
      visible: pointer && _hovered && (previous ? _page > 0 : _page < widget.itemCount - 1),
      child: FrostButton.icon(
        icon: previous ? icons.chevronLeft : icons.chevronRight,
        label: previous ? labels.previous : labels.next,
        style: FrostIconButtonStyle.onMedia,
        size: FrostControlSize.compact,
        onPressed: () {
          _focus.requestFocus();
          unawaited(_move(_page + (previous ? -1 : 1), animate: true));
        },
      ),
    );
    final indicator = widget.showsIndicator && widget.itemCount > 1
        ? FrostPageIndicator(
            count: widget.itemCount,
            current: _page,
            onSelected: (page) {
              _focus.requestFocus();
              unawaited(_move(page, animate: true));
            },
            onMedia: widget.indicatorPlacement == FrostPageIndicatorPlacement.overlay,
          )
        : null;
    final content = MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.itemCount > 0)
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 && notification is ScrollStartNotification && notification.dragDetails != null) {
                  _request++;
                  _motion.stop();
                }
                return false;
              },
              child: PageView.builder(
                key: ObjectKey(_pages),
                controller: _pages,
                itemCount: widget.itemCount,
                physics: _zoomedMedia.containsValue(_page) ? const NeverScrollableScrollPhysics() : null,
                itemBuilder: (context, index) => FrostPagerMediaScope(index: index, onZoomChanged: _zoom, child: widget.itemBuilder(context, index)),
                onPageChanged: _changed,
              ),
            ),
          if (widget.itemCount > 0) ...[
            PositionedDirectional(
              start: _mediaControlInset,
              top: 0,
              bottom: 0,
              child: Center(child: arrow(previous: true)),
            ),
            PositionedDirectional(
              end: _mediaControlInset,
              top: 0,
              bottom: 0,
              child: Center(child: arrow(previous: false)),
            ),
          ],
          if (indicator != null && widget.indicatorPlacement == FrostPageIndicatorPlacement.overlay)
            PositionedDirectional(
              start: 0,
              end: 0,
              bottom: _mediaControlInset,
              child: Center(
                child: DecoratedBox(
                  decoration: ShapeDecoration(color: FrostThemeTokens.of(context).onMediaScrim, shape: const StadiumBorder()),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _indicatorHorizontalPadding, vertical: _indicatorVerticalPadding),
                    child: indicator,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _key,
      child: FocusableActionDetector(
        focusNode: _focus,
        enabled: widget.itemCount > 0,
        onShowFocusHighlight: (value) => setState(() => _showsFocus = value),
        child: AnimatedContainer(
          duration: FrostMotion.hover,
          foregroundDecoration: BoxDecoration(
            border: Border.all(
              color: FrostThemeTokens.of(context).focus.withValues(alpha: _showsFocus ? 1 : 0),
              width: FrostMetrics.focusBorderWidth,
            ),
          ),
          child: widget.indicatorPlacement == FrostPageIndicatorPlacement.below && indicator != null
              ? Column(
                  children: [
                    Expanded(child: content),
                    const SizedBox(height: _indicatorBelowGap),
                    indicator,
                  ],
                )
              : content,
        ),
      ),
    );
  }
}
