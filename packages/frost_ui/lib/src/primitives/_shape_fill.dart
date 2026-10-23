import 'package:flutter/painting.dart';

/// Impeller can leave interior seams when filling asymmetric superellipses.
/// Owners with an existing outer clip paint a rectangle beneath that clip instead.
/// Keep strokes on the original shape so focus and border geometry are unchanged.
bool frostNeedsClippedFill(ShapeBorder shape, TextDirection direction) {
  if (shape is! RoundedSuperellipseBorder) return false;
  final radius = shape.borderRadius.resolve(direction);
  return radius.topLeft != radius.topRight || radius.topLeft != radius.bottomLeft || radius.topLeft != radius.bottomRight;
}
