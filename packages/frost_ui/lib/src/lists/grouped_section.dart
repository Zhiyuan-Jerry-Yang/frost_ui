import 'package:flutter/widgets.dart';

import '../foundation/radius.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../primitives/keyline.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';
import '_contiguous_rows.dart';

// Group captions sit close to their container, without adding outer margins.
const _captionGap = 6.0;

/// Contiguous rows share an opaque module and concentric outer highlights.
class FrostGroupedSection extends StatelessWidget {
  const FrostGroupedSection({this.header, this.footer, required this.children, super.key});
  final String? header, footer;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final inset = FrostGap.of(context).rowInset;
    Widget caption(String text) => Padding(
      padding: EdgeInsets.symmetric(horizontal: inset),
      child: FrostText(text, role: FrostTextRole.footnote, tone: FrostTextTone.secondary),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header case final header?) ...[caption(header), const SizedBox(height: _captionGap)],
        FrostSurface(
          role: FrostSurfaceRole.module,
          edge: FrostSurfaceEdge.none,
          elevated: false,
          borderRadius: FrostRadius.borderRadius(FrostRadius.xl),
          child: FrostKeyline(
            leadingRoom: 0,
            trailingRoom: 0,
            edgeDistanceStart: 0,
            edgeDistanceEnd: 0,
            insideContainer: true,
            contentStart: inset,
            child: FrostContiguousRows(corners: FrostRadius.borderRadius(FrostRadius.inner(FrostRadius.xl, 0)), children: children),
          ),
        ),
        if (footer case final footer?) ...[const SizedBox(height: _captionGap), caption(footer)],
      ],
    );
  }
}
