import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/sizes.dart';
import '_button_control.dart';
import '_button_types.dart';
import '_toolbar_geometry.dart';

/// Dynamic glyphs share button paint, feedback, focus and semantics. A loading
/// glyph here does not disable an action such as stopping a browser request.
class FrostDynamicIconButton extends StatelessWidget {
  const FrostDynamicIconButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.media = false,
    this.toolbar = false,
    this.size = FrostControlSize.compact,
    this.focusNode,
    super.key,
  });
  final String label;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool media, toolbar;
  final FrostControlSize size;
  final FocusNode? focusNode;
  @override
  Widget build(BuildContext context) => FrostButtonControl(
    label: label,
    onPressed: onPressed,
    focusNode: focusNode,
    iconStyle: toolbar ? null : (media ? FrostIconButtonStyle.onMedia : FrostIconButtonStyle.plain),
    showsLabel: !toolbar,
    variant: FrostButtonVariant.plain,
    size: size,
    geometry: toolbar ? frostToolbarButtonGeometry(context) : null,
    iconWidget: AnimatedSwitcher(
      duration: FrostMotion.duration(context, FrostMotion.layoutFade),
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      child: icon,
    ),
  );
}
