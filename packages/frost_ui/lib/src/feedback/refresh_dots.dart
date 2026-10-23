import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';

class FrostRefreshDots extends StatefulWidget {
  const FrostRefreshDots({super.key});
  @override
  State<FrostRefreshDots> createState() => _RefreshDotsState();
}

class _RefreshDotsState extends State<FrostRefreshDots> with SingleTickerProviderStateMixin {
  static const _dotsWidth = 24.0; // Fixed layout width of the three refresh dots, independent of density.
  late final AnimationController _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _animation.stop();
    } else if (!_animation.isAnimating) {
      _animation.repeat();
    }
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: FrostScope.labelsOf(context).refreshing,
    child: SizedBox(
      width: _dotsWidth,
      height: FrostControlSize.regular.iconSize,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var index = 0; index < 3; index++)
              Transform.translate(
                offset: Offset(0, _reduceMotion ? 0 : -4 * math.max(0, math.sin((_animation.value - index * .16) * math.pi * 2))),
                child: SizedBox.square(
                  dimension: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: FrostThemeTokens.of(context).textPrimary, shape: BoxShape.circle),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

/// Keeps the scroll viewport and existing content in place during refresh.
class FrostDotsRefreshIndicator extends StatefulWidget {
  const FrostDotsRefreshIndicator({required this.child, required this.onRefresh, super.key});
  final Widget child;
  final RefreshCallback onRefresh;
  @override
  State<FrostDotsRefreshIndicator> createState() => _DotsRefreshIndicatorState();
}

class _DotsRefreshIndicatorState extends State<FrostDotsRefreshIndicator> {
  bool _visible = false;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      RefreshIndicator.noSpinner(
        onRefresh: widget.onRefresh,
        onStatusChange: (status) {
          final visible = status != null && status != RefreshIndicatorStatus.done && status != RefreshIndicatorStatus.canceled;
          if (mounted && visible != _visible) setState(() => _visible = visible);
        },
        child: widget.child,
      ),
      Positioned(
        top: 8,
        left: 16,
        right: 16,
        child: IgnorePointer(
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: FrostMotion.duration(context, FrostMotion.feedback),
            child: Center(
              child: TickerMode(enabled: _visible, child: const FrostRefreshDots()),
            ),
          ),
        ),
      ),
    ],
  );
}
