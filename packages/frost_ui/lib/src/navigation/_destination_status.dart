import 'dart:math' as math;

import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/widgets.dart';

import '../display/count_badge.dart';
import '../feedback/progress.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/typography.dart';
import '../motion/rolling_text.dart';
import '../primitives/presence.dart';

// The count and progress ring share this spacing with the preceding label.
const _statusGap = 6.0;
const _percentScale = 100;

/// Library-only destination data, shared by both sidebar item forms.
class FrostDestinationStatus extends InheritedWidget {
  const FrostDestinationStatus({required this.badge, required this.progress, required super.child, super.key});
  final int badge;
  final double? progress;

  static FrostDestinationStatus? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostDestinationStatus>();

  static String labelOf(BuildContext context, String label) {
    final status = of(context);
    if (status == null || (status.badge <= 0 && status.progress == null)) return label;
    final description = FrostScope.labelsOf(
      context,
    ).navigationStatus(math.max(0, status.badge), status.progress == null ? null : (status.progress! * _percentScale).round());
    return '$label, $description';
  }

  static Widget decorateIcon(BuildContext context, Widget icon, {double expansion = 0}) {
    final status = of(context);
    if (status == null) return icon;
    // The icon remains visible while only its badge fades during expansion.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned.fill(
          child: Opacity(opacity: (1 - expansion * 2).clamp(0.0, 1.0), child: const SizedBox.expand().frostBadge(status.badge)),
        ),
      ],
    );
  }

  @override
  bool updateShouldNotify(FrostDestinationStatus oldWidget) => badge != oldWidget.badge || progress != oldWidget.progress;
}

/// Retains outgoing values until Presence finishes; digits never flash zero.
class FrostDestinationTrailing extends StatefulWidget {
  const FrostDestinationTrailing({required this.status, required this.ink, super.key});
  final FrostDestinationStatus status;
  final Color ink;
  @override
  State<FrostDestinationTrailing> createState() => _DestinationTrailingState();
}

class _DestinationTrailingState extends State<FrostDestinationTrailing> {
  late int _count = widget.status.badge;
  late double _progress = widget.status.progress ?? 0;
  @override
  void didUpdateWidget(FrostDestinationTrailing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status.badge > 0) _count = widget.status.badge;
    if (widget.status.progress case final progress?) _progress = progress;
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    // During sidebar collapse the fading label area can be narrower than the
    // status itself. Keep its natural geometry and clip the outgoing content.
    child: OverflowBox(
      fit: OverflowBoxFit.deferToChild,
      minWidth: 0,
      maxWidth: double.infinity,
      alignment: AlignmentDirectional.centerEnd,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostPresence(
              visible: widget.status.badge > 0,
              effect: FrostPresenceEffect.expand,
              axis: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: _statusGap),
                child: FrostRollingText(
                  _count.toString(),
                  style: FrostTypography.of(context).style(FrostTextRole.footnote, numeric: true).copyWith(color: widget.ink),
                ),
              ),
            ),
            FrostPresence(
              visible: widget.status.progress != null,
              effect: FrostPresenceEffect.expand,
              axis: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: _statusGap),
                child: FrostProgressInk(
                  ink: widget.ink,
                  child: FrostProgressRing(value: _progress, size: FrostControlSize.compact, semanticLabel: ''),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
