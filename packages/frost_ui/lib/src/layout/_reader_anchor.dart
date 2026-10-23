import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// Layout corrections stop below a thousandth of a logical pixel. The retry cap
// guards invalid application content that changes geometry on every layout.
const _anchorTolerance = .001;
const _maximumAnchorCorrections = 8;

class FrostReaderScrollView extends CustomScrollView {
  const FrostReaderScrollView({required this.viewportKey, super.controller, super.slivers, super.key});
  final GlobalKey viewportKey;
  @override
  Widget buildViewport(BuildContext context, ViewportOffset offset, AxisDirection axisDirection, List<Widget> slivers) =>
      _ReaderViewport(key: viewportKey, offset: offset, axisDirection: axisDirection, contentTop: MediaQuery.paddingOf(context).top, slivers: slivers);
}

class _ReaderViewport extends Viewport {
  _ReaderViewport({required this.contentTop, required super.offset, required super.axisDirection, required super.slivers, super.key});
  final double contentTop;
  @override
  FrostReaderViewport createRenderObject(BuildContext context) => FrostReaderViewport(
    contentTop: contentTop,
    offset: offset,
    axisDirection: axisDirection,
    crossAxisDirection: Viewport.getDefaultCrossAxisDirection(context, axisDirection),
  );
  @override
  void updateRenderObject(BuildContext context, covariant FrostReaderViewport renderObject) {
    super.updateRenderObject(context, renderObject);
    renderObject.contentTop = contentTop;
  }
}

/// A text anchor refers to a UTF-16 position (the framework's TextPosition),
/// with the original offset inside that line. Non-text items retain a fraction
/// of their height. Stable content keys/order preserve the render identities.
class FrostReadingAnchor {
  FrostReadingAnchor({required this.item, required this.viewportY, this.paragraph, this.position, this.lineOffset, this.heightFraction});
  final RenderBox item;
  final double viewportY;
  final RenderParagraph? paragraph;
  final TextPosition? position;
  final double? lineOffset, heightFraction;
  VoidCallback? release;
}

class FrostReaderViewport extends RenderViewport {
  FrostReaderViewport({required this.contentTop, required super.offset, required super.axisDirection, required super.crossAxisDirection});
  double contentTop;
  FrostReadingAnchor? _pending;

  /// Capture before descendant typography rebuilds invalidate the old text.
  void preserveReadingPosition(BuildContext context) {
    _pending?.release?.call();
    final anchor = _pending = readAnchor();
    if (anchor == null) return;
    void retain(Element element) {
      if (element is RenderObjectElement && element.renderObject == anchor.item) {
        final handle = KeepAliveHandle();
        KeepAliveNotification(handle).dispatch(element);
        anchor.release = handle.dispose;
        return;
      }
      element.visitChildren(retain);
    }

    (context as Element).visitChildren(retain);
  }

  FrostReadingAnchor? readAnchor() {
    RenderBox? item;
    double nearest = double.infinity;
    void findItem(RenderObject object) {
      if (object is RenderBox && object.hasSize && (object.parent is RenderSliverMultiBoxAdaptor || object.parent is RenderSliverToBoxAdapter)) {
        final rect = MatrixUtils.transformRect(object.getTransformTo(this), Offset.zero & object.size);
        if (rect.bottom > contentTop && rect.top < size.height) {
          final distance = rect.top <= contentTop ? 0.0 : rect.top - contentTop;
          if (distance < nearest) {
            nearest = distance;
            item = object;
          }
        }
        return;
      }
      object.visitChildren(findItem);
    }

    visitChildren(findItem);
    if (item == null) return null;
    final root = item!;
    final rect = MatrixUtils.transformRect(root.getTransformTo(this), Offset.zero & root.size);
    final target = contentTop.clamp(rect.top, rect.bottom);
    RenderParagraph? paragraph;
    void findParagraph(RenderObject object) {
      if (paragraph != null) return;
      if (object is RenderParagraph && object.hasSize) {
        final rect = MatrixUtils.transformRect(object.getTransformTo(this), Offset.zero & object.size);
        if (rect.top <= target && rect.bottom > target && object.text.toPlainText().isNotEmpty) paragraph = object;
        // A root paragraph owns the positions of its WidgetSpans.
        return;
      }
      object.visitChildren(findParagraph);
    }

    findParagraph(root);
    if (paragraph case final text?) {
      final origin = MatrixUtils.transformPoint(text.getTransformTo(this), Offset.zero);
      final x = text.textDirection == TextDirection.rtl ? text.size.width : 0.0;
      final position = text.getPositionForOffset(Offset(x, target - origin.dy));
      final caret = text.getOffsetForCaret(position, Rect.zero);
      return FrostReadingAnchor(item: root, viewportY: target, paragraph: text, position: position, lineOffset: target - origin.dy - caret.dy);
    }
    return FrostReadingAnchor(item: root, viewportY: target, heightFraction: root.size.height == 0 ? 0 : (target - rect.top) / root.size.height);
  }

  double anchorY(FrostReadingAnchor anchor) {
    final text = anchor.paragraph;
    final point = text == null
        ? Offset(0, anchor.item.size.height * anchor.heightFraction!)
        : MatrixUtils.transformPoint(text.getTransformTo(anchor.item), text.getOffsetForCaret(anchor.position!, Rect.zero) + Offset(0, anchor.lineOffset!));
    if (anchor.item.parent case final RenderSliverMultiBoxAdaptor sliver) {
      // Kept-alive items have a zero paint transform. Their layout offset is
      // still valid, so use layout coordinates until the correction reveals it.
      final data = anchor.item.parentData! as SliverMultiBoxAdaptorParentData;
      final cross = data is SliverGridParentData ? (data.crossAxisOffset ?? 0.0) : 0.0;
      return MatrixUtils.transformPoint(
        sliver.getTransformTo(this),
        Offset(cross + point.dx, data.layoutOffset! - sliver.constraints.scrollOffset + point.dy),
      ).dy;
    }
    return MatrixUtils.transformPoint(anchor.item.getTransformTo(this), point).dy;
  }

  @override
  void dispose() {
    _pending?.release?.call();
    _pending = null;
    super.dispose();
  }

  @override
  void performLayout() {
    final anchor = _pending;
    final data = anchor?.item.parentData;
    final lazyData = data is SliverMultiBoxAdaptorParentData ? data : null;
    final keptAlive = lazyData?.keepAlive;
    // A shrinking long paragraph can leave the old pixel viewport entirely.
    // Retain only this item during this layout, without making the list eager
    // or changing the application's persistent keep-alive policy.
    if (lazyData != null) lazyData.keepAlive = true;
    try {
      super.performLayout();
      if (anchor == null) return;
      for (var attempt = 0; attempt < _maximumAnchorCorrections; attempt++) {
        if (!anchor.item.attached || (anchor.paragraph != null && !anchor.paragraph!.attached)) return;
        var delta = 0.0;
        // Read descendant geometry in the framework's permitted callback phase,
        // after all slivers have laid out, before correcting this same viewport.
        invokeLayoutCallback<BoxConstraints>((_) => delta = anchorY(anchor) - anchor.viewportY);
        if (!delta.isFinite || delta.abs() < _anchorTolerance) break;
        final current = offset.pixels;
        offset.correctBy(delta);
        super.performLayout();
        // A physical scroll boundary wins when the document is now shorter
        // than the available viewport.
        if ((offset.pixels - current).abs() < _anchorTolerance) break;
      }
    } finally {
      if (lazyData != null) lazyData.keepAlive = keptAlive!;
      anchor?.release?.call();
      _pending = null;
    }
  }
}
