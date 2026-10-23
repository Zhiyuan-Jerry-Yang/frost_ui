import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';

/// Internal selection feedback shared by navigation and toggle buttons.
class FrostSelectionFeedback extends StatefulWidget {
  const FrostSelectionFeedback({required this.selected, required this.foreground, required this.background, required this.builder, super.key});
  final bool selected;
  final Color foreground, background;
  final Widget Function(BuildContext context, Color foreground, Color background, Animation<double> iconScale) builder;
  @override
  State<FrostSelectionFeedback> createState() => _FrostSelectionFeedbackState();
}

class _FrostSelectionFeedbackState extends State<FrostSelectionFeedback> {
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
    tween: ColorTween(end: widget.foreground),
    duration: FrostMotion.duration(context, FrostMotion.hover),
    curve: FrostMotion.hoverCurve,
    builder: (context, ink, _) => TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: widget.background),
      duration: FrostMotion.duration(context, FrostMotion.hover),
      curve: FrostMotion.hoverCurve,
      // Navigation changes colour without an instantaneous graphic-size reset.
      builder: (context, fill, _) => widget.builder(context, ink!, fill!, const AlwaysStoppedAnimation(1)),
    ),
  );
}
