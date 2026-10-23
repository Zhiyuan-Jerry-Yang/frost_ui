import 'dart:math' as math;
import 'package:flutter/widgets.dart';

import '../foundation/sizes.dart';
import '../foundation/tokens.dart';

/// Internal foreground supplied by buttons; not exported by frost_ui.dart.
class FrostActivityForeground extends InheritedWidget {
  const FrostActivityForeground({required this.color, required super.child, super.key});
  final Color color;
  static Color? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostActivityForeground>()?.color;
  @override
  bool updateShouldNotify(FrostActivityForeground oldWidget) => color != oldWidget.color;
}

/// Eight neutral radial strokes; the caller owns the loading announcement.
class FrostActivityIndicator extends StatefulWidget {
  const FrostActivityIndicator({this.size = FrostControlSize.regular, required this.semanticLabel, super.key});
  final FrostControlSize size;
  final String? semanticLabel;
  @override
  State<FrostActivityIndicator> createState() => _FrostActivityIndicatorState();
}

class _FrostActivityIndicatorState extends State<FrostActivityIndicator> with SingleTickerProviderStateMixin {
  // Indicator diameters are independent of control/icon geometry.
  static const _compactDiameter = 16.0, _regularDiameter = 20.0, _largeDiameter = 28.0;
  // Eight 125 ms steps make a complete clockwise turn.
  static const _turn = Duration(milliseconds: 1000);
  // A stationary frame breathes over one complete two-second cycle.
  static const _pulse = Duration(milliseconds: 2000);
  late final _clock = AnimationController(vsync: this, animationBehavior: AnimationBehavior.preserve);
  bool? _reduced;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced != reduced) {
      _reduced = reduced;
      _clock.value = 0;
      _clock.repeat(period: reduced ? _pulse : _turn);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diameter = switch (widget.size) {
      FrostControlSize.compact => _compactDiameter,
      FrostControlSize.regular => _regularDiameter,
      FrostControlSize.large => _largeDiameter,
    };
    final drawing = SizedBox.square(
      dimension: diameter,
      child: CustomPaint(painter: _ActivityPainter(_clock, FrostActivityForeground.maybeOf(context) ?? FrostThemeTokens.of(context).textSecondary, _reduced!)),
    );
    return widget.semanticLabel == null ? ExcludeSemantics(child: drawing) : Semantics(label: widget.semanticLabel, liveRegion: true, child: drawing);
  }
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter(this.clock, this.color, this.reduced) : super(repaint: clock);
  final Animation<double> clock;
  final Color color;
  final bool reduced;
  // Stroke proportions follow the radial indicator, not spacing tokens.
  static const _strokes = 8, _innerRadius = .225, _outerRadius = .475, _strokeRatio = .1, _minimumStroke = 1.5;
  static const _tailOpacity = .2, _pulseMinimum = .6;
  @override
  void paint(Canvas canvas, Size size) {
    final diameter = size.shortestSide;
    final head = reduced ? 0 : (clock.value * _strokes).floor() % _strokes;
    final phase = clock.value <= .5 ? clock.value * 2 : (1 - clock.value) * 2;
    final opacity = reduced ? _pulseMinimum + (1 - _pulseMinimum) * Curves.easeInOutSine.transform(phase) : 1.0;
    final paint = Paint()
      ..strokeWidth = math.max(_minimumStroke, diameter * _strokeRatio)
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < _strokes; index++) {
      final behind = (head - index) % _strokes;
      paint.color = color.withValues(alpha: color.a * (1 - (1 - _tailOpacity) * behind / (_strokes - 1)) * opacity);
      final angle = -math.pi / 2 + math.pi * 2 * index / _strokes;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(size.center(Offset.zero) + direction * diameter * _innerRadius, size.center(Offset.zero) + direction * diameter * _outerRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_ActivityPainter oldDelegate) => color != oldDelegate.color || reduced != oldDelegate.reduced || clock != oldDelegate.clock;
}
