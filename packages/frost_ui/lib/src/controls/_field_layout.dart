import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_material_reveal.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/presence.dart';
import '../primitives/text.dart';

export '../foundation/_control_geometry.dart' show frostControlGeometry;

// Field labels have a fixed separation independent of density and page gaps.
const frostFieldLabelGap = 6.0;
// Field content insets follow the size, rather than the page spacing scale.
const _compactInset = 10.0, _regularInset = 12.0, _largeInset = 14.0;

double frostFieldInset(FrostControlSize size) => switch (size) {
  FrostControlSize.compact => _compactInset,
  FrostControlSize.regular => _regularInset,
  FrostControlSize.large => _largeInset,
};

/// Shared internal layout for field labels and replaceable supporting text.
class FrostFieldLayout extends StatelessWidget {
  const FrostFieldLayout({
    required this.child,
    this.label,
    this.help,
    this.error,
    this.supportingTrailing,
    this.enabled = true,
    this.supportingPresence = false,
    this.stretch = true,
    super.key,
  });
  final Widget child;
  final Widget? supportingTrailing;
  final String? label, help, error;
  final bool enabled;
  final bool supportingPresence;
  final bool stretch;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final message = error ?? help;
    final duration = FrostMotion.duration(context, FrostMotion.layoutFade);
    Widget dim(Widget child) =>
        FrostAnimatedMaterialReveal(opacity: enabled ? 1 : .38, duration: FrostMotion.duration(context, FrostMotion.hover), child: child);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: stretch ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      children: [
        if (label case final label?) ...[
          dim(
            DefaultTextStyle(
              style: TextStyle(color: tokens.textSecondary),
              child: FrostText(label, role: FrostTextRole.subheadline),
            ),
          ),
          const SizedBox(height: frostFieldLabelGap),
        ],
        child,
        _SupportingPresence(
          visible: message != null || supportingTrailing != null,
          enabled: supportingPresence,
          child: FrostMotionSize(
            duration: duration,
            alignment: AlignmentDirectional.topStart,
            child: FrostLayoutCrossfade(
              layoutIdentity: (message, error != null, supportingTrailing != null),
              settleDuration: Duration.zero,
              child: message == null && supportingTrailing == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: FrostGap.inline),
                      child: dim(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: message == null
                                  ? const SizedBox.shrink()
                                  : DefaultTextStyle(
                                      style: TextStyle(color: error == null ? tokens.textSecondary : tokens.negativeInk),
                                      child: FrostText(message, role: FrostTextRole.footnote),
                                    ),
                            ),
                            if (supportingTrailing case final trailing?) ...[if (message != null) const SizedBox(width: FrostGap.related), trailing],
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportingPresence extends StatelessWidget {
  const _SupportingPresence({required this.visible, required this.enabled, required this.child});
  final bool visible, enabled;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      enabled ? FrostPresence(visible: visible, effect: FrostPresenceEffect.expand, alignment: AlignmentDirectional.topStart, child: child) : child;
}
