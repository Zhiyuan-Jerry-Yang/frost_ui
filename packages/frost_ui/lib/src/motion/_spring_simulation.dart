import 'dart:math' as math;
import 'package:flutter/physics.dart';

/// Keeps retargeted geometry between its current position and its new target.
/// For a critically/over-damped spring the fast decay root bounds the initial
/// velocity that can reach the target without crossing it. Reversal discards
/// velocity pointing away from the new target, without resetting position.
/// Explicit under-damped confirmation springs retain their small rebound.
SpringSimulation frostSpringSimulation(SpringDescription spring, double start, double end, double velocity) {
  final discriminant = spring.damping * spring.damping - 4 * spring.mass * spring.stiffness;
  if (discriminant >= -1e-8) {
    final distance = end - start;
    final decay = (spring.damping + math.sqrt(math.max(0, discriminant))) / (2 * spring.mass);
    velocity = distance == 0 ? 0 : (velocity * distance.sign).clamp(0.0, distance.abs() * decay) * distance.sign;
  }
  return SpringSimulation(spring, start, end, velocity, snapToEnd: true);
}
