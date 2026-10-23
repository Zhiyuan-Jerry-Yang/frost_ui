import 'package:flutter/painting.dart';

/// Alpha-only colours for compositing masks, independent of media text.
abstract final class FrostMask {
  /// Only alpha is used by masks; RGB carries no text or surface semantics.
  static const opaque = Color(0xFFFFFFFF);
}
