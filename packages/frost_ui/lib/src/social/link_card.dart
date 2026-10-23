import 'package:flutter/widgets.dart';

import '../feedback/skeleton.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_media_shape.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '../primitives/media_frame.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';

// Link previews share the Module material and text inset.
const _textInset = 16.0;
const _thumbnailExtent = 64.0;
const _largeRatio = 1.91;

enum FrostLinkCardStyle { row, large }

/// A Module-material link preview. The application owns navigation. A missing
/// or failed image removes the whole image slot; pending images are not bones.
/// Use the explicit skeleton constructor only when its shape is known.
class FrostLinkCard extends StatelessWidget {
  const FrostLinkCard({required this.title, required this.url, this.description, this.image, this.style = FrostLinkCardStyle.row, this.onPressed, super.key});
  factory FrostLinkCard.skeleton({
    required FrostLinkCardStyle style,
    required bool image,
    required String title,
    required String? description,
    required String host,
    Key? key,
  }) => _SkeletonLinkCard(style: style, hasImage: image, title: title, description: description, host: host, key: key);
  final String title;
  final String? description;
  final Uri url;
  final ImageProvider? image;
  final FrostLinkCardStyle style;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    Widget body(bool available) => _LinkBody(
      title: title,
      description: description,
      host: url.host,
      style: style,
      onPressed: onPressed,
      image: available
          ? FrostMediaFrame(
              image: image,
              radius: style == FrostLinkCardStyle.row ? FrostRadius.sm : 0,
              placeholderBuilder: (_, progress) => const SizedBox.shrink(),
              errorBuilder: (_, error) => const SizedBox.shrink(),
            )
          : null,
    );
    return image == null ? body(false) : _LinkImageAvailability(key: ObjectKey(image), image: image!, builder: (_, available) => body(available));
  }
}

class _SkeletonLinkCard extends FrostLinkCard {
  _SkeletonLinkCard({required super.style, required this.hasImage, required super.title, required super.description, required this.host, super.key})
    : super(url: Uri());
  final bool hasImage;
  final String host;
  @override
  Widget build(BuildContext context) => _LinkBody(
    title: title,
    description: description,
    host: host,
    style: style,
    image: hasImage
        ? FrostMediaFrame(
            radius: style == FrostLinkCardStyle.row ? FrostRadius.sm : 0,
            child: FrostSkeletonLeaf(
              child: ColoredBox(color: FrostThemeTokens.of(context).fill, child: const SizedBox.expand()),
            ),
          )
        : null,
  ).frostSkeleton(true);
}

class _LinkBody extends StatelessWidget {
  const _LinkBody({required this.title, required this.description, required this.host, required this.style, this.image, this.onPressed});
  final String title, host;
  final String? description;
  final FrostLinkCardStyle style;
  final Widget? image;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final text = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FrostText(title, tone: FrostTextTone.primary, role: FrostTextRole.callout, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (description case final description?) ...[
          const SizedBox(height: FrostGap.inline),
          FrostText(description, role: FrostTextRole.footnote, tone: FrostTextTone.secondary, maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        const SizedBox(height: FrostGap.inline),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FrostIcon(FrostIconSet.of(context).link, size: FrostControlSize.compact.iconSize, color: FrostThemeTokens.of(context).textTertiary),
            const SizedBox(width: FrostGap.inline),
            Expanded(
              child: FrostText(host, role: FrostTextRole.caption, tone: FrostTextTone.tertiary),
            ),
          ],
        ),
      ],
    );
    // The Module is the card boundary. Decorative link artwork must not acquire
    // a second media outline (visible as a pale rim around transparent logos).
    final content = style == FrostLinkCardStyle.row
        ? Padding(
            padding: const EdgeInsets.all(_textInset),
            child: Row(
              children: [
                if (image != null) ...[
                  SizedBox.square(
                    dimension: _thumbnailExtent,
                    child: FrostMediaInnerStroke(enabled: false, child: image!),
                  ),
                  const SizedBox(width: FrostGap.related),
                ],
                Expanded(child: text),
              ],
            ),
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (image != null)
                AspectRatio(
                  aspectRatio: _largeRatio,
                  child: FrostMediaInnerStroke(enabled: false, child: image!),
                ),
              Padding(padding: const EdgeInsets.all(_textInset), child: text),
            ],
          );
    final shape = FrostRadius.shape(context, FrostRadius.lg);
    final surface = FrostSurface(
      role: FrostSurfaceRole.module,
      borderRadius: FrostRadius.borderRadius(FrostRadius.lg),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: FrostClickSurfaceVisuals.scaled(
          child: FrostClickSurface(
            customBorder: shape,
            onTap: onPressed,
            child: onPressed == null ? content : IgnorePointer(child: ExcludeFocus(child: content)),
          ),
        ),
      ),
    );
    return onPressed == null ? surface : Semantics(button: true, label: title, value: host, onTap: onPressed, excludeSemantics: true, child: surface);
  }
}

/// Own only the availability subscription; FrostMediaFrame still owns image
/// rendering/fade. ImageCache shares resolution, so this does not decode twice.
class _LinkImageAvailability extends StatefulWidget {
  const _LinkImageAvailability({required this.image, required this.builder, super.key});
  final ImageProvider image;
  final Widget Function(BuildContext context, bool available) builder;
  @override
  State<_LinkImageAvailability> createState() => _LinkImageAvailabilityState();
}

class _LinkImageAvailabilityState extends State<_LinkImageAvailability> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  bool _failed = false, _synchronous = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener!);
    _stream = stream;
    _failed = false;
    _listener = ImageStreamListener(
      (image, synchronous) => image.dispose(),
      onError: (Object error, StackTrace? stack) {
        if (!mounted) return;
        if (_synchronous) {
          _failed = true;
        } else {
          setState(() => _failed = true);
        }
      },
    );
    _synchronous = true;
    stream.addListener(_listener!);
    _synchronous = false;
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, !_failed);
}
