import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../primitives/icon.dart';
import '_button_control.dart';
import '_button_types.dart';

// Tabs and filter chips share the same small close affordance and input path.
const frostCloseSize = 20.0;
const _closeIconSize = 14.0;

class FrostCloseControl extends StatelessWidget {
  const FrostCloseControl({required this.label, required this.onPressed, this.maximumHitHeight = frostCloseSize, this.foreground, super.key});
  final String label;
  final VoidCallback onPressed;
  final double maximumHitHeight;
  final Color? foreground;
  @override
  Widget build(BuildContext context) => FrostButtonControl(
    icon: FrostScope.configOf(context).icons.close,
    iconWidget: foreground == null
        ? null
        : TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: foreground),
            duration: FrostMotion.duration(context, FrostMotion.hover),
            curve: FrostMotion.hoverCurve,
            builder: (context, color, _) => FrostIcon(FrostScope.configOf(context).icons.close, size: _closeIconSize, color: color),
          ),
    label: label,
    iconStyle: FrostIconButtonStyle.plain,
    geometry: FrostButtonGeometry(
      horizontalInset: 0,
      verticalInset: 0,
      minimumWidth: frostCloseSize,
      alignment: MainAxisAlignment.center,
      visualHeight: frostCloseSize,
      iconSize: _closeIconSize,
      maximumHitHeight: maximumHitHeight,
    ),
    onPressed: onPressed,
  );
}
