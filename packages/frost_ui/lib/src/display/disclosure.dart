import 'package:flutter/widgets.dart';

import '../foundation/_control_geometry.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_material_reveal.dart';
import '../motion/layout_crossfade.dart';
import '../motion/spring.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/text.dart';

// A quarter turn changes the same directional chevron into a down arrow.
const _expandedTurns = .25;

class FrostDisclosure extends StatefulWidget {
  const FrostDisclosure({required this.title, required this.child, this.initiallyExpanded = false, this.expanded, this.onExpansionChanged, super.key});
  final String title;
  final Widget child;
  final bool initiallyExpanded;
  final bool? expanded;
  final ValueChanged<bool>? onExpansionChanged;
  @override
  State<FrostDisclosure> createState() => _DisclosureState();
}

class _DisclosureState extends State<FrostDisclosure> {
  late bool _expanded = widget.initiallyExpanded;
  final _glass = FrostRevealHandle();
  late bool _visualExpanded = widget.expanded ?? widget.initiallyExpanded;
  late bool _requestedExpanded = _visualExpanded;
  void _requestVisual() {
    if (expanded == _requestedExpanded) return;
    _requestedExpanded = expanded;
    if (expanded) {
      _glass.cancelClose();
      _visualExpanded = true;
    } else if (_glass.hasNestedGlass && _glass.nestedProgress > 0) {
      _glass.prepareClose().then((ready) {
        if (ready && mounted && !expanded) setState(() => _visualExpanded = false);
      });
    } else {
      _visualExpanded = false;
    }
  }

  bool get expanded => widget.expanded ?? _expanded;
  bool get enabled => widget.expanded == null || widget.onExpansionChanged != null;
  @override
  void didUpdateWidget(FrostDisclosure oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != null && widget.expanded == null) _expanded = oldWidget.expanded!;
    _requestVisual();
  }

  void _toggle() {
    final next = !expanded;
    if (widget.expanded == null) {
      setState(() {
        _expanded = next;
        _requestVisual();
      });
    }
    widget.onExpansionChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final geometry = frostControlGeometry(context, FrostControlSize.regular, role: FrostTextRole.headline);
    final turns = Directionality.of(context) == TextDirection.rtl ? -_expandedTurns : _expandedTurns;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FrostBleed(
          amount: FrostGap.of(context).hitInset,
          child: Builder(
            builder: (context) => Semantics(
              label: widget.title,
              button: true,
              expanded: expanded,
              enabled: enabled,
              onTap: enabled ? _toggle : null,
              excludeSemantics: true,
              child: FrostClickSurface(
                onTap: enabled ? _toggle : null,
                customBorder: FrostRadius.shape(context, FrostRadius.sm),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: geometry.height),
                  child: Padding(
                    padding: frostBleedOutsetsOf(context).add(EdgeInsets.symmetric(vertical: geometry.verticalInset)),
                    child: Row(
                      children: [
                        Expanded(
                          child: FrostText(widget.title, role: FrostTextRole.headline, tone: FrostTextTone.primary, numeric: true),
                        ),
                        const SizedBox(width: FrostGap.related),
                        AnimatedRotation(
                          turns: expanded ? turns : 0,
                          duration: FrostMotion.duration(context, FrostMotion.feedback),
                          curve: FrostMotion.hoverCurve,
                          child: FrostIcon(
                            FrostIconSet.of(context).chevronRight,
                            size: FrostControlSize.compact.iconSize,
                            color: FrostThemeTokens.of(context).textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        FrostSpringBuilder(
          value: _visualExpanded ? 1 : 0,
          spring: FrostMotion.standard,
          child: ExcludeFocus(
            excluding: !expanded,
            child: ExcludeSemantics(
              excluding: !expanded,
              child: TickerMode(
                enabled: expanded,
                child: FrostMotionSize(
                  duration: FrostMotion.duration(context, FrostMotion.layoutFade),
                  alignment: AlignmentDirectional.topStart,
                  child: Padding(
                    padding: const EdgeInsets.only(top: FrostGap.related),
                    child: widget.child,
                  ),
                ),
              ),
            ),
          ),
          builder: (context, progress, child) => ClipRect(
            child: Align(
              alignment: AlignmentDirectional.topStart,
              heightFactor: progress.clamp(0.0, 1.0),
              child: Offstage(
                offstage: progress <= 0,
                child: FrostMaterialReveal(opacity: progress.clamp(0.0, 1.0), handle: _glass, contentOnly: true, child: child!),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
