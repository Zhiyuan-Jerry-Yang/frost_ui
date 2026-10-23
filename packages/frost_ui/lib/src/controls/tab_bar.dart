import 'package:flutter/material.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/_layout_scope.dart';
import '../foundation/_tab_metrics.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/click_surface.dart' show FrostClickFeedback;
import '../primitives/icon.dart';
import '../primitives/keyline.dart';

class FrostTab {
  const FrostTab({required this.label, this.icon});
  final String label;
  final FrostIconData? icon;
}

/// Native tabs with a spring for click-driven indicator motion. The supplied
/// controller remains the sole owner of content selection and page dragging.
class FrostTabBar extends StatefulWidget {
  const FrostTabBar({required this.tabs, this.controller, this.scrollable = false, this.onTap, super.key});

  final List<FrostTab> tabs;
  final TabController? controller;
  final bool scrollable;
  final ValueChanged<int>? onTap;

  @override
  State<FrostTabBar> createState() => _AppTabBarState();
}

class _AppTabBarState extends State<FrostTabBar> with TickerProviderStateMixin {
  _IndicatorTabController? _visual;
  final _focused = <int>{};

  void _bindController() {
    final source = widget.controller ?? DefaultTabController.of(context);
    if (_visual?.source != source) {
      _visual?.dispose();
      _visual = _IndicatorTabController(source: source, vsync: this, context: () => context);
    }
    _visual!.reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindController();
  }

  @override
  void didUpdateWidget(FrostTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindController();
  }

  @override
  void dispose() {
    _visual?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final geometry = frostControlGeometry(context, FrostControlSize.regular, role: FrostTextRole.callout);
    final style = FrostTypography.of(context).style(FrostTextRole.callout);
    final direction = Directionality.of(context) == TextDirection.ltr ? 1.0 : -1.0;
    final contentWidth = widget.scrollable || FrostSizeClass.of(context) != FrostSizeClass.compact;
    return FrostBleed(
      amount: frostTabInset,
      child: TabBar(
        controller: _visual,
        tabs: [
          for (var i = 0; i < widget.tabs.length; i++)
            _TabLabel(
              tab: widget.tabs[i],
              index: i,
              controller: _visual!.source,
              height: geometry.height - frostTabIndicatorHeight,
              focused: _focused.contains(i),
            ),
        ],
        isScrollable: contentWidth,
        tabAlignment: contentWidth ? TabAlignment.start : TabAlignment.fill,
        dividerColor: tokens.separator,
        dividerHeight: 1 / MediaQuery.devicePixelRatioOf(context),
        labelPadding: EdgeInsets.zero,
        padding: EdgeInsets.zero,
        labelStyle: style,
        unselectedLabelStyle: style,
        labelColor: tokens.textPrimary,
        unselectedLabelColor: tokens.textSecondary,
        indicator: FrostTabIndicator(
          color: tokens.keyGraphicOn(tokens.surface),
          progress: _visual!.animation,
          textOffsets: [for (final tab in widget.tabs) tab.icon == null ? 0 : direction * (FrostControlSize.regular.iconSize + frostTabIconGap) / 2],
        ),
        indicatorSize: TabBarIndicatorSize.label,
        indicatorPadding: EdgeInsets.zero,
        indicatorWeight: frostTabIndicatorHeight,
        automaticIndicatorColorAdjustment: false,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        splashFactory: NoSplash.splashFactory,
        splashBorderRadius: FrostRadius.borderRadius(FrostRadius.sm),
        mouseCursor: SystemMouseCursors.click,
        onTap: widget.onTap,
        onFocusChange: (focused, index) => setState(() {
          if (focused) {
            _focused.add(index);
          } else {
            _focused.remove(index);
          }
        }),
        // Flutter derives label bounds for RTL/scrolling; only progress springs.
        indicatorAnimation: TabIndicatorAnimation.linear,
      ),
    );
  }
}

class _TabLabel extends StatefulWidget {
  const _TabLabel({required this.tab, required this.index, required this.controller, required this.height, required this.focused});
  final FrostTab tab;
  final int index;
  final TabController controller;
  final double height;
  final bool focused;
  @override
  State<_TabLabel> createState() => _TabLabelState();
}

class _TabLabelState extends State<_TabLabel> {
  bool _hovered = false;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final tokens = FrostThemeTokens.of(context);
      final selected = widget.controller.index == widget.index;
      final style = FrostTypography.of(context).style(FrostTextRole.callout);
      // Reserve selected typography, so changing weight cannot shift the mark.
      final painter = TextPainter(
        text: TextSpan(text: widget.tab.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FrostClickFeedbackVisual(
          states: {if (_hovered) WidgetState.hovered, if (widget.focused) WidgetState.focused},
          feedback: FrostClickFeedback.quiet,
          shape: FrostRadius.shape(context, FrostRadius.sm),
          clipsContent: false,
          child: SizedBox(
            height: widget.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: frostTabInset),
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: selected ? tokens.textPrimary : tokens.textSecondary),
                duration: FrostMotion.duration(context, FrostMotion.hover),
                curve: FrostMotion.hoverCurve,
                builder: (context, color, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.tab.icon case final icon?) ...[
                      FrostIcon(icon, size: FrostControlSize.regular.iconSize, color: color),
                      const SizedBox(width: frostTabIconGap),
                    ],
                    Flexible(
                      child: SizedBox(
                        width: width,
                        child: FrostSkeletonText(
                          child: Text(
                            widget.tab.label,
                            style: style.copyWith(color: color),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
    },
  );
}

class _IndicatorTabController extends TabController {
  _IndicatorTabController({required this.source, required super.vsync, required this.context})
    : _motion = AnimationController.unbounded(vsync: vsync, value: source.animation!.value),
      _lastIndex = source.index,
      super(length: source.length, initialIndex: source.index) {
    source.addListener(_selectionChanged);
    source.animation!.addListener(_sourceProgressChanged);
    // A bar can appear while its content controller is already moving (for
    // example after a responsive header rebuild). No new index notification
    // will arrive, so explicitly adopt the in-flight selection's target.
    if (source.indexIsChanging) FrostMotion.springTo(context(), _motion, source.index.toDouble(), FrostMotion.snappy);
  }

  final TabController source;
  final BuildContext Function() context;
  final AnimationController _motion;
  int _lastIndex;
  bool _dragging = false;
  bool _reduceMotion = false;

  set reduceMotion(bool value) {
    _reduceMotion = value;
    if (value) _motion.value = source.index.toDouble();
  }

  void _selectionChanged() {
    if (_lastIndex != source.index) {
      _lastIndex = source.index;
      if (_dragging && !source.indexIsChanging) {
        _motion.value = source.animation!.value;
      } else {
        _dragging = false;
        FrostMotion.springTo(context(), _motion, source.index.toDouble(), FrostMotion.snappy);
      }
    }
    notifyListeners();
  }

  void _sourceProgressChanged() {
    if (source.indexIsChanging) return;
    final progress = source.animation!.value;
    // PageView gestures drive this continuously. An index assignment or a
    // zero-duration animateTo is handled by the selection listener instead.
    if (progress != source.index || _dragging) {
      _dragging = progress != source.index;
      _motion.value = _reduceMotion ? source.index.toDouble() : progress;
    }
  }

  @override
  Animation<double> get animation => _motion.view;
  @override
  Duration get animationDuration => source.animationDuration;
  @override
  int get index => source.index;
  @override
  set index(int value) => source.index = value;
  @override
  int get previousIndex => source.previousIndex;
  @override
  bool get indexIsChanging => source.indexIsChanging;
  @override
  double get offset => source.offset;
  @override
  set offset(double value) => source.offset = value;
  @override
  void animateTo(int value, {Duration? duration, Curve curve = Curves.ease}) {
    _dragging = false;
    source.animateTo(value, duration: _reduceMotion ? Duration.zero : duration, curve: curve);
  }

  @override
  void dispose() {
    source.removeListener(_selectionChanged);
    source.animation?.removeListener(_sourceProgressChanged);
    _motion.dispose();
    super.dispose();
  }
}
