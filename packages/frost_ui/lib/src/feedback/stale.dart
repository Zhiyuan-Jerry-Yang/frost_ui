import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../motion/_material_reveal.dart';
import 'loading_gate.dart';

// Existing content remains recognizable while a refresh is pending.
const _staleOpacity = .5;

extension FrostStaleX on Widget {
  /// Keeps readable content during refresh. The shared gate avoids flashing
  /// short requests and keeps a visible wait for at least 400 ms.
  Widget frostStale(bool stale) => FrostLoadingGate(
    loading: stale,
    builder: (context, shown) => Semantics(
      container: true,
      value: stale || shown ? FrostScope.labelsOf(context).loading : null,
      child: FrostAnimatedMaterialReveal(
        opacity: shown ? _staleOpacity : 1,
        duration: FrostMotion.duration(context, FrostMotion.hover),
        curve: FrostMotion.hoverCurve,
        child: Builder(
          builder: (context) {
            final opacity = FrostContentRevealScope.maybeOf(context)?.opacity ?? 1;
            return IgnorePointer(
              ignoring: shown || opacity < 1,
              child: ExcludeFocus(excluding: shown || opacity < 1, child: this),
            );
          },
        ),
      ),
    ),
  );
}
