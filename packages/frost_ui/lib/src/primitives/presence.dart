import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../motion/_material_reveal.dart';
import '_presence_entry.dart';
import '_presence_material.dart';
import '_presence_timing.dart';

enum FrostPresenceEffect { fadeScale, expand }

/// Animates changes after mounting, retaining outgoing content until dismissed.
/// Use fadeScale in a fixed slot; use expand when surrounding layout must move.
class FrostPresence extends StatefulWidget {
  const FrostPresence({
    required this.visible,
    required this.child,
    this.effect = FrostPresenceEffect.fadeScale,
    this.axis = Axis.vertical,
    this.alignment = Alignment.center,
    super.key,
  });
  final bool visible;
  final Widget child;
  final FrostPresenceEffect effect;
  final Axis axis;
  final AlignmentGeometry alignment;
  @override
  State<FrostPresence> createState() => _FrostPresenceState();
}

class _FrostPresenceState extends State<FrostPresence> with SingleTickerProviderStateMixin {
  // Presence scales only four percent, independently of press feedback.
  static const _hiddenScale = .96;
  late final _progress = AnimationController(vsync: this, value: widget.visible ? 1 : 0, animationBehavior: AnimationBehavior.preserve);
  late bool _present = widget.visible;
  bool? _reduced;
  Duration? _duration;
  bool _entered = false;
  final _glass = FrostRevealHandle();
  @override
  void initState() {
    super.initState();
    _progress.addListener(_finished);
  }

  void _finished() {
    if (_progress.value == 0 && !widget.visible && _present) setState(() => _present = false);
  }

  void _animate() {
    if (widget.visible) {
      _glass.cancelClose();
    } else if (_glass.hasNestedGlass && _glass.nestedProgress > 0) {
      _glass.prepareClose().then((ready) {
        if (ready && mounted && !widget.visible) _startAnimation();
      });
      return;
    }
    _startAnimation();
  }

  void _startAnimation() {
    if (widget.visible) _present = true;
    if (_progress.value == (widget.visible ? 1 : 0)) {
      // A pending close can start on the tick before a reopen rebuilds.
      _progress.stop();
      if (!widget.visible) _present = false;
      return;
    }
    _progress.animateTo(
      widget.visible ? 1 : 0,
      duration: _reduced == true ? FrostMotion.reducedFade : _duration ?? (widget.visible ? FrostMotion.reveal : FrostMotion.dismiss),
      curve: widget.visible ? Curves.easeOutCubic : Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(FrostPresence oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visible != widget.visible) _animate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _duration = FrostPresenceTiming.of(context);
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (_reduced != null && _reduced != reduced) {
      _reduced = reduced;
      _animate();
    }
    _reduced = reduced;
    if (!_entered) {
      _entered = true;
      if (widget.visible && FrostPresenceEntry.of(context)) {
        _progress.value = 0;
        _animate();
      }
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_present) return const SizedBox.shrink();
    Widget content = IgnorePointer(
      ignoring: !widget.visible,
      child: ExcludeFocus(
        excluding: !widget.visible,
        child: ExcludeSemantics(excluding: !widget.visible, child: widget.child),
      ),
    );
    content = FrostMaterialRevealTransition(
      opacity: _progress,
      handle: _glass,
      contentOnly: !FrostPresenceMaterial.of(context),
      child: FrostPresenceMaterial(enabled: false, child: content),
    );
    if (_reduced != true) {
      content = switch (widget.effect) {
        FrostPresenceEffect.fadeScale => ScaleTransition(
          scale: _progress.drive(Tween(begin: _hiddenScale, end: 1.0)),
          alignment: widget.alignment.resolve(Directionality.of(context)),
          child: content,
        ),
        FrostPresenceEffect.expand => AnimatedBuilder(
          animation: _progress,
          child: content,
          builder: (context, child) => ClipRect(
            child: Align(
              alignment: widget.alignment,
              widthFactor: widget.axis == Axis.horizontal ? _progress.value : 1,
              heightFactor: widget.axis == Axis.vertical ? _progress.value : 1,
              child: child,
            ),
          ),
        ),
      };
    }
    return content;
  }
}
