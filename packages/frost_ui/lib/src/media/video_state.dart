import 'package:flutter/foundation.dart';

/// The application owns playback. Out-of-range positions and nonpositive
/// durations are normalized by FrostVideoFrame without changing this value.
@immutable
class FrostVideoState {
  const FrostVideoState({
    required this.playing,
    required this.position,
    required this.duration,
    this.buffered = Duration.zero,
    this.muted = false,
    this.looping = false,
    this.fullscreen = false,
    this.buffering = false,
  });
  final bool playing, muted, fullscreen, buffering, looping;
  final Duration position, duration, buffered;
}
