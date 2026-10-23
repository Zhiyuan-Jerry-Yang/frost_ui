import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../controls/_close_control.dart';
import '../controls/buttons.dart';
import '../feedback/_skeleton_geometry.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_material_reveal.dart';
import '../motion/_spring_simulation.dart';

/// Browser-style tabs: their order, the one in front, and where new ones go.
/// A tab is any object the app keeps per tab (its router, say), compared by
/// identity. The controller never empties: the last tab cannot be closed.
class FrostTabsController<T extends Object> extends ChangeNotifier {
  FrostTabsController({required T initial, this.onRemoved}) : _tabs = [initial];

  /// Called with each tab that leaves for good, after listeners have heard
  /// of it; the tab's widgets unmount in the next frame.
  final ValueChanged<T>? onRemoved;

  final List<T> _tabs;
  int _active = 0;

  /// The last tab opened in the background from the front tab: the next one
  /// goes after it, so links opened in turn keep their order.
  int? _lastOpened;

  List<T> get tabs => List.unmodifiable(_tabs);
  int get length => _tabs.length;
  int get activeIndex => _active;
  T get active => _tabs[_active];

  /// Opens [tab] after the front tab (and after the tabs it already opened
  /// in the background), in front unless [activate] is false.
  void open(T tab, {bool activate = true}) {
    final index = (_lastOpened ?? _active) + 1;
    _tabs.insert(index, tab);
    if (activate) {
      _active = index;
      _lastOpened = null;
    } else {
      _lastOpened = index;
    }
    notifyListeners();
  }

  void activate(int index) {
    RangeError.checkValidIndex(index, _tabs);
    if (index == _active) return;
    _active = index;
    _lastOpened = null;
    notifyListeners();
  }

  /// Brings forward the tab [delta] places away, wrapping around.
  void activateRelative(int delta) => activate((_active + delta) % _tabs.length);

  /// Closes the tab at [index]; closing the front tab brings forward the one
  /// after it, or the one before at the end. False for the last tab.
  bool close(int index) {
    RangeError.checkValidIndex(index, _tabs);
    if (_tabs.length < 2) return false;
    final removed = _tabs.removeAt(index);
    final wasActive = index == _active;
    if (index < _active || wasActive && _active == _tabs.length) _active--;
    final opened = _lastOpened;
    _lastOpened = wasActive || opened == null || opened == index
        ? null
        : index < opened
        ? opened - 1
        : opened;
    notifyListeners();
    onRemoved?.call(removed);
    return true;
  }

  /// Moves the tab at [from] to [to], keeping the front tab in front.
  void move(int from, int to) {
    RangeError.checkValidIndex(from, _tabs);
    RangeError.checkValidIndex(to, _tabs);
    if (from == to) return;
    final active = _tabs[_active];
    _tabs.insert(to, _tabs.removeAt(from));
    _active = _tabs.indexOf(active);
    _lastOpened = null;
    notifyListeners();
  }

  /// Replaces every tab with [tab].
  void replaceAll(T tab) {
    final removed = [..._tabs];
    _tabs
      ..clear()
      ..add(tab);
    _active = 0;
    _lastOpened = null;
    notifyListeners();
    removed.forEach(onRemoved ?? (_) {});
  }

  @override
  void dispose() {
    _tabs.forEach(onRemoved ?? (_) {});
    _tabs.clear();
    super.dispose();
  }
}

/// Keeps every opened tab's page alive and shows the front one, fading it
/// in over the one it replaces. Tabs opened in the background are built when
/// first shown. Hidden tabs keep their state but have tickers, focus,
/// pointer input and semantics turned off.
///
/// Owns the browser tab keys while focus is inside: Ctrl+T ([onNewTab]),
/// Ctrl+W and Ctrl+F4, Ctrl+(Shift+)Tab, Ctrl+PageUp/PageDown, Ctrl+1–8,
/// Ctrl+9 and Ctrl+Shift+T ([onReopen]).
class FrostTabHost<T extends Object> extends StatefulWidget {
  const FrostTabHost({required this.controller, required this.builder, this.onNewTab, this.onReopen, super.key});

  final FrostTabsController<T> controller;
  final Widget Function(BuildContext context, T tab) builder;
  final VoidCallback? onNewTab;
  final VoidCallback? onReopen;

  @override
  State<FrostTabHost<T>> createState() => _FrostTabHostState<T>();
}

class _FrostTabHostState<T extends Object> extends State<FrostTabHost<T>> with SingleTickerProviderStateMixin {
  final _built = <T>{};
  final _scopes = <T, FocusScopeNode>{};
  late final _fade = AnimationController(vsync: this, duration: FrostMotion.layoutFade, value: 1);
  late T _shown;
  T? _outgoing;

  @override
  void initState() {
    super.initState();
    _shown = widget.controller.active;
    _built.add(_shown);
    widget.controller.addListener(_changed);
    // Take focus when nothing has it, so the tab keys work from the start.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final primary = FocusManager.instance.primaryFocus;
      if (mounted && (primary == null || primary is FocusScopeNode && primary.focusedChild == null)) _scopes[_shown]?.requestFocus();
    });
  }

  @override
  void didUpdateWidget(FrostTabHost<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _changed();
    }
  }

  void _changed() {
    // Focus follows the front tab when it was in a tab (the closed one too),
    // or nowhere, so the tab keys keep working.
    final primary = FocusManager.instance.primaryFocus;
    final hadFocus = _scopes.values.any((node) => node.hasFocus) || primary == null || primary is FocusScopeNode && primary.focusedChild == null;
    final controller = widget.controller;
    final tabs = controller.tabs;
    _built.removeWhere((tab) => !tabs.contains(tab));
    final gone = [
      for (final MapEntry(:key, :value) in _scopes.entries)
        if (!tabs.contains(key)) value,
    ];
    if (gone.isNotEmpty) {
      _scopes.removeWhere((tab, _) => !tabs.contains(tab));
      // Detached once the tab's widgets have unmounted.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final node in gone) {
          node.dispose();
        }
      });
    }
    final active = controller.active;
    if (active != _shown) {
      final previous = _shown;
      _shown = active;
      _built.add(active);
      _outgoing = tabs.contains(previous) && !MediaQuery.disableAnimationsOf(context) ? previous : null;
      if (_outgoing == null) {
        _fade.value = 1;
      } else {
        final outgoing = _outgoing;
        _fade.forward(from: 0).whenCompleteOrCancel(() {
          if (mounted && _outgoing == outgoing && !_fade.isAnimating) setState(() => _outgoing = null);
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && hadFocus && _shown == active) _scopes[active]?.requestFocus();
      });
    } else if (_outgoing != null && !tabs.contains(_outgoing)) {
      _outgoing = null;
    }
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _fade.dispose();
    for (final node in _scopes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Widget _slot(T tab) {
    final active = tab == _shown;
    final visible = active || tab == _outgoing;
    final scope = _scopes.putIfAbsent(tab, () => FocusScopeNode(debugLabel: 'Tab'));
    // The structure stays the same whether a tab is in front or not, so its
    // state survives every switch.
    return KeyedSubtree(
      key: ObjectKey(tab),
      child: Offstage(
        offstage: !visible,
        child: FrostMaterialRevealTransition(
          contentOnly: true,
          opacity: active ? _fade : kAlwaysCompleteAnimation,
          child: ExcludeSemantics(
            excluding: !active,
            child: IgnorePointer(
              ignoring: !active,
              child: TickerMode(
                enabled: active,
                child: ExcludeFocus(
                  excluding: !active,
                  child: FocusScope(
                    node: scope,
                    child: Builder(builder: (context) => widget.builder(context, tab)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final apple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;
    SingleActivator key(LogicalKeyboardKey key, {bool shift = false}) => SingleActivator(key, control: !apple, meta: apple, shift: shift);
    void select(int index) => controller.activate(math.min(index, controller.length - 1));
    const digits = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
    ];
    return CallbackShortcuts(
      bindings: {
        key(LogicalKeyboardKey.keyT): ?widget.onNewTab,
        key(LogicalKeyboardKey.keyT, shift: true): ?widget.onReopen,
        key(LogicalKeyboardKey.keyW): () => controller.close(controller.activeIndex),
        key(LogicalKeyboardKey.f4): () => controller.close(controller.activeIndex),
        key(LogicalKeyboardKey.tab): () => controller.activateRelative(1),
        key(LogicalKeyboardKey.tab, shift: true): () => controller.activateRelative(-1),
        key(LogicalKeyboardKey.pageDown): () => controller.activateRelative(1),
        key(LogicalKeyboardKey.pageUp): () => controller.activateRelative(-1),
        for (final (index, digit) in digits.indexed) key(digit): () => select(index),
        key(LogicalKeyboardKey.digit9): () => select(controller.length - 1),
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The front tab paints last, over the one fading out.
          for (final tab in controller.tabs)
            if (_built.contains(tab) && tab != _shown) _slot(tab),
          _slot(_shown),
        ],
      ),
    );
  }
}

/// What a tab shows of its page.
@immutable
class FrostTabLabel {
  const FrostTabLabel({required this.title, this.leading});

  final String title;

  /// A 16 dp mark before the title: the page's icon or picture.
  final Widget? leading;
}

/// The row of tabs for a [FrostTabsController], sized to its tabs and
/// followed by a new-tab button; place it where the rest of the row is free
/// (the page owns the tab strip and its hit targets).
///
/// Tabs share the width up to [maxTabWidth] each. Opening, closing and
/// moving tabs animate on springs: a new tab grows from nothing in place,
/// a closed one shrinks away, and the others slide to their new places,
/// also while one is dragged along the row. After a tab is closed with the
/// pointer the others keep their width until the pointer leaves the row,
/// so the next close button lands under it. A middle click closes a tab.
class FrostTabStrip<T extends Object> extends StatefulWidget {
  const FrostTabStrip({
    required this.controller,
    required this.label,
    required this.closeTooltip,
    required this.newTabTooltip,
    required this.newTabIcon,
    required this.onNewTab,
    this.maxTabWidth = 220,
    this.minTabWidth = 40,
    super.key,
  });

  final FrostTabsController<T> controller;
  final FrostTabLabel Function(BuildContext context, T tab) label;
  final String closeTooltip;
  final String newTabTooltip;
  final FrostIconData newTabIcon;
  final VoidCallback onNewTab;
  final double maxTabWidth;

  /// Below this the row stops shrinking its tabs and clips the overflow.
  final double minTabWidth;

  @override
  State<FrostTabStrip<T>> createState() => _FrostTabStripState<T>();
}

/// One animated quantity: it moves to a new target on a spring from where
/// it is, keeping its velocity, and snaps when told to.
class _Spring {
  double value = 0;
  double target = 0;
  SpringSimulation? _simulation;
  double _start = 0;

  bool get moving => _simulation != null;

  void snap(double to) {
    value = target = to;
    _simulation = null;
  }

  void retarget(double to, double now) {
    if (to == target) return;
    final velocity = _simulation?.dx(now - _start) ?? 0;
    target = to;
    _simulation = frostSpringSimulation(FrostMotion.snappy, value, to, velocity);
    _start = now;
  }

  /// Advances to [now]; whether it is still moving.
  bool step(double now) {
    final simulation = _simulation;
    if (simulation == null) return false;
    final time = now - _start;
    if (simulation.isDone(time)) {
      snap(target);
      return false;
    }
    value = simulation.x(time);
    return true;
  }
}

class _StripItem<T> {
  _StripItem(this.tab);

  final T tab;
  final x = _Spring();
  final width = _Spring();
  bool leaving = false;

  /// Not laid out yet: it starts at its place with no width.
  bool fresh = true;
}

class _FrostTabStripState<T extends Object> extends State<FrostTabStrip<T>> with SingleTickerProviderStateMixin {
  final _items = <_StripItem<T>>[];
  // Strip time in seconds, advanced by the ticker so springs follow the
  // frame clock; it stands still while nothing moves.
  double _now = 0;
  double _idleAt = 0;
  late final Ticker _ticker = createTicker(_tick);
  final _newTab = _Spring();
  double? _lastMaxWidth;
  double _tabWidth = 0;

  /// The width tabs keep after a pointer close, until the pointer leaves.
  double? _heldWidth;
  T? _hovered;
  T? _dragging;
  T? _middlePressed;
  bool _closePressed = false;

  @override
  void initState() {
    super.initState();
    _sync();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(FrostTabStrip<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _changed();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _ticker.dispose();
    super.dispose();
  }

  void _changed() => setState(_sync);

  /// Follows the controller's order; tabs that left stay where they were
  /// while they shrink away.
  void _sync() {
    final tabs = widget.controller.tabs;
    final known = {for (final item in _items) item.tab: item};
    final next = [for (final tab in tabs) known[tab] ?? _StripItem<T>(tab)];
    for (final (index, item) in _items.indexed) {
      if (tabs.contains(item.tab)) continue;
      item.leaving = true;
      next.insert(math.min(index, next.length), item);
    }
    _items
      ..clear()
      ..addAll(next);
    if (_dragging != null && !tabs.contains(_dragging)) _dragging = null;
  }

  void _tick(Duration elapsed) {
    final now = _now = _idleAt + elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    var moving = _newTab.step(now);
    for (final item in _items) {
      moving = item.x.step(now) | moving;
      moving = item.width.step(now) | moving;
    }
    _items.removeWhere((item) => item.leaving && !item.width.moving && item.width.value == 0);
    if (!moving) {
      _ticker.stop();
      _idleAt = now;
    }
    setState(() {});
  }

  /// Lays the tabs out at their targets and sets every spring moving there.
  /// A window resize moves them at once; only changes to the row animate.
  void _layout(double maxWidth, double buttonWidth, bool reduced) {
    // The first layout places the row as it is; nothing grows in.
    final first = _lastMaxWidth == null;
    final resized = first || _lastMaxWidth != maxWidth;
    _lastMaxWidth = maxWidth;
    final count = _items.where((item) => !item.leaving).length;
    final fitted = count == 0 ? 0.0 : ((maxWidth - buttonWidth) / count).clamp(widget.minTabWidth, widget.maxTabWidth);
    final held = _heldWidth;
    _tabWidth = held != null && held * count <= maxWidth - buttonWidth ? held : fitted;
    final now = _now;
    var x = 0.0;
    for (final item in _items) {
      final width = item.leaving ? 0.0 : _tabWidth;
      if (item.fresh) {
        item.fresh = false;
        item.x.snap(x);
        item.width.snap(first ? width : 0);
      }
      if (reduced || resized && !item.width.moving) {
        item.width.snap(width);
      } else {
        item.width.retarget(width, now);
      }
      if (item.tab != _dragging) {
        if (reduced || resized && !item.x.moving) {
          item.x.snap(x);
        } else {
          item.x.retarget(x, now);
        }
      }
      x += width;
    }
    if (reduced || resized) {
      _newTab.snap(x);
    } else {
      _newTab.retarget(x, now);
    }
    if (reduced) _items.removeWhere((item) => item.leaving);
    final moving = _newTab.moving || _items.any((item) => item.x.moving || item.width.moving);
    if (moving && !_ticker.isActive) _ticker.start();
  }

  void _close(T tab, {required bool pointer}) {
    final controller = widget.controller;
    final index = controller.tabs.indexOf(tab);
    if (index < 0 || controller.length < 2) return;
    // Hold the widths only while the row still has room for them.
    if (pointer && index < controller.length - 1) _heldWidth = _tabWidth;
    controller.close(index);
  }

  void _dragUpdate(_StripItem<T> item, double delta) {
    final controller = widget.controller;
    final count = controller.length;
    final x = (item.x.value + delta).clamp(0.0, math.max(0.0, (count - 1) * _tabWidth)).toDouble();
    item.x.snap(x);
    final index = controller.tabs.indexOf(item.tab);
    final target = _tabWidth <= 0 ? index : ((x + _tabWidth / 2) / _tabWidth).floor().clamp(0, count - 1);
    if (index >= 0 && target != index) {
      controller.move(index, target);
    } else {
      setState(() {});
    }
  }

  void _dragEnd() {
    if (_dragging == null) return;
    setState(() => _dragging = null);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final buttonWidth = math.min(height, 40.0);
        _layout(constraints.maxWidth, buttonWidth, reduced);
        final controller = widget.controller;
        final active = controller.active;
        final closable = controller.length > 1;
        final placed = [..._items.where((item) => item.tab != _dragging), ..._items.where((item) => item.tab == _dragging)];
        // Separators sit between two tabs that are neither in front nor
        // under the pointer, as in a browser.
        final plain = [for (final item in _items) !item.leaving && item.tab != active && item.tab != _hovered];
        final width = math.min(constraints.maxWidth, _newTab.value + buttonWidth);
        return MouseRegion(
          onExit: (_) {
            if (_heldWidth != null) setState(() => _heldWidth = null);
          },
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRect(
              child: Stack(
                children: [
                  for (final item in placed)
                    if (item.width.value > .5)
                      Positioned(
                        key: ObjectKey(item.tab),
                        left: item.x.value,
                        top: 0,
                        bottom: 0,
                        width: item.width.value,
                        child: _tab(
                          context,
                          item,
                          active: item.tab == active,
                          closable: closable,
                          height: height,
                          separator: () {
                            final index = _items.indexOf(item);
                            if (index <= 0 || !plain[index]) return false;
                            for (var before = index - 1; before >= 0; before--) {
                              if (!_items[before].leaving) return plain[before];
                            }
                            return false;
                          }(),
                        ),
                      ),
                  Positioned(
                    left: _newTab.value,
                    top: 0,
                    bottom: 0,
                    width: buttonWidth,
                    child: Center(
                      child: FrostButton.icon(icon: widget.newTabIcon, label: widget.newTabTooltip, size: FrostControlSize.compact, onPressed: widget.onNewTab),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static const _separatorLength = 16.0; // Fixed length of the vertical separator between background tabs.
  static const _separatorThickness = 1.0; // Thickness of the vertical separator between background tabs.

  Widget _tab(BuildContext context, _StripItem<T> item, {required bool active, required bool closable, required double height, required bool separator}) {
    final tokens = FrostThemeTokens.of(context);
    final label = widget.label(context, item.tab);
    final width = item.width.value;
    final opacity = _tabWidth <= 0 ? 1.0 : (width / _tabWidth).clamp(0.0, 1.0);
    final compact = width < 72;
    final hovered = _hovered == item.tab;
    final close = closable && (!compact || active)
        ? Listener(
            onPointerDown: (_) => _closePressed = true,
            child: FrostCloseControl(
              label: widget.closeTooltip,
              maximumHitHeight: math.max(frostCloseSize, height - FrostGap.inline * 2),
              onPressed: () => _close(item.tab, pointer: true),
            ),
          )
        : null;
    final leading = label.leading;
    final ink = active ? tokens.selectionInk : tokens.textSecondary;
    final content = compact
        ? Center(child: close ?? (leading == null ? null : SizedBox.square(dimension: 16, child: leading)))
        : Row(
            children: [
              if (leading != null) ...[SizedBox.square(dimension: 16, child: leading), const SizedBox(width: FrostGap.related)],
              Expanded(
                child: FrostSkeletonText(child: Text(label.title, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis)),
              ),
              if (close != null) ...[const SizedBox(width: FrostGap.inline), close],
            ],
          );
    const pillMargin = EdgeInsets.symmetric(horizontal: FrostGap.inline, vertical: FrostGap.inline);
    final pillHeight = height - pillMargin.vertical;
    final pill = AnimatedContainer(
      duration: FrostMotion.duration(context, FrostMotion.hover),
      curve: FrostMotion.hoverCurve,
      margin: pillMargin,
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : FrostGap.related),
      decoration: ShapeDecoration(
        color: active
            ? tokens.selectionFill
            : hovered
            ? tokens.fillSubtle
            : tokens.fillSubtle.withValues(alpha: 0),
        shape: FrostRadius.shape(context, FrostRadius.forHeight(pillHeight)),
      ),
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: ink),
        duration: FrostMotion.duration(context, FrostMotion.hover),
        curve: FrostMotion.hoverCurve,
        builder: (context, color, _) => DefaultTextStyle(
          style: FrostTypography.of(context).style(FrostTextRole.footnote).copyWith(color: color),
          child: IconTheme(
            data: IconThemeData(color: color),
            child: content,
          ),
        ),
      ),
    );
    return IgnorePointer(
      ignoring: item.leaving,
      child: Opacity(
        opacity: opacity,
        child: Semantics(
          button: true,
          selected: active,
          label: label.title,
          onTap: () => _activate(item.tab),
          child: MouseRegion(
            onEnter: (_) => setState(() => _hovered = item.tab),
            onExit: (_) {
              if (_hovered == item.tab) setState(() => _hovered = null);
            },
            child: Listener(
              onPointerDown: (event) {
                if (event.buttons == kMiddleMouseButton) {
                  _middlePressed = item.tab;
                } else if (event.buttons == kPrimaryMouseButton && !_closePressed) {
                  _activate(item.tab);
                }
                _closePressed = false;
              },
              onPointerUp: (event) {
                if (_middlePressed == item.tab) _close(item.tab, pointer: true);
                _middlePressed = null;
              },
              onPointerCancel: (_) => _middlePressed = null,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => setState(() => _dragging = item.tab),
                onHorizontalDragUpdate: (details) => _dragUpdate(item, details.delta.dx),
                onHorizontalDragEnd: (_) => _dragEnd(),
                onHorizontalDragCancel: _dragEnd,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    pill,
                    if (separator)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: SizedBox(
                          width: _separatorThickness,
                          height: _separatorLength,
                          child: ColoredBox(color: tokens.separator),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _activate(T tab) {
    final index = widget.controller.tabs.indexOf(tab);
    if (index >= 0) widget.controller.activate(index);
  }
}
