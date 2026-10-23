import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../controls/_button_control.dart';
import '../controls/buttons.dart';
import '../display/_avatar_size.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../primitives/_presence_entry.dart';
import '../primitives/click_surface.dart';
import '../primitives/presence.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';

// Thread geometry is independent of the nesting content's natural height.
const _avatarExtent = 32.0;
const _connectionGap = 4.0;
const _bendRadius = 8.0;
const _lineWidth = 1.5;
const _maximumIndent = 3;

class FrostThreadItem extends StatelessWidget {
  const FrostThreadItem({
    required this.avatar,
    required this.author,
    required this.body,
    this.meta,
    this.actions,
    this.onPressed,
    this.contextMenu = const [],
    super.key,
  });
  final Widget avatar, body;
  final String author;
  final String? meta;
  final Widget? actions;
  final VoidCallback? onPressed;
  final List<FrostMenuEntry> contextMenu;
  @override
  Widget build(BuildContext context) => FrostContextMenuRegion(
    entries: contextMenu,
    child: FrostClickSurface(
      onTap: onPressed,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AvatarAnchor(
            child: SizedBox(
              width: _avatarExtent,
              height: _avatarExtent,
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: FrostSurfaceScope.maybeOf(context)?.background ?? FrostThemeTokens.of(context).canvas),
                child: FrostAvatarSizeScope(size: FrostAvatarSize.regular, child: avatar),
              ),
            ),
          ),
          const SizedBox(width: FrostGap.related),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: FrostGap.inline,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FrostText(author, role: FrostTextRole.headline, tone: FrostTextTone.primary),
                    if (meta case final meta?) FrostText(meta, role: FrostTextRole.footnote, tone: FrostTextTone.tertiary),
                  ],
                ),
                const SizedBox(height: FrostGap.inline),
                body,
                if (actions case final actions?) ...[const SizedBox(height: FrostGap.related), actions],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// A recursive thread block. Keep keys stable when inserting replies so only
/// new replies animate. For long conversations, put top-level replies in a
/// lazy ListView/SliverList (one top-level FrostThread per builder item), rather
/// than placing every top-level reply in one eager replies list.
class FrostThread extends StatefulWidget {
  const FrostThread({required this.item, this.replies = const [], this.collapsedReplyCount = 0, this.onShowReplies, super.key})
    : assert(collapsedReplyCount >= 0);
  final FrostThreadItem item;
  final List<FrostThread> replies;
  final int collapsedReplyCount;
  final VoidCallback? onShowReplies;
  @override
  State<FrostThread> createState() => _ThreadState();
}

class _ThreadState extends State<FrostThread> {
  Set<Object> _entering = {};
  Object _identity(int index, FrostThread reply) => reply.key ?? index;
  @override
  void didUpdateWidget(FrostThread oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = {for (final (index, reply) in oldWidget.replies.indexed) _identity(index, reply)};
    _entering = {
      for (final (index, reply) in widget.replies.indexed)
        if (!old.contains(_identity(index, reply))) _identity(index, reply),
    };
  }

  @override
  Widget build(BuildContext context) {
    final depth = context.dependOnInheritedWidgetOfExactType<_ThreadDepth>()?.depth ?? 0;
    return _ThreadLayout(
      indent: depth < _maximumIndent ? _avatarExtent + FrostGap.related : 0,
      direction: Directionality.of(context),
      ink: FrostThemeTokens.of(context).threadLine,
      replyCount: widget.replies.length,
      children: [
        widget.item,
        for (final (index, reply) in widget.replies.indexed)
          FrostPresenceEntry(
            key: ValueKey(_identity(index, reply)),
            animate: _entering.contains(_identity(index, reply)),
            child: FrostPresence(
              visible: true,
              effect: FrostPresenceEffect.expand,
              alignment: AlignmentDirectional.topStart,
              child: Padding(
                padding: const EdgeInsets.only(top: FrostGap.related),
                child: _ThreadDepth(depth: depth + 1, child: reply),
              ),
            ),
          ),
        if (widget.collapsedReplyCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: FrostGap.related),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FrostButtonControl(
                presentation: FrostButtonPresentation.link,
                label: FrostScope.labelsOf(context).showReplies(widget.collapsedReplyCount),
                variant: FrostButtonVariant.plain,
                size: FrostControlSize.compact,
                onPressed: widget.onShowReplies,
              ),
            ),
          ),
      ],
    );
  }
}

class _ThreadDepth extends InheritedWidget {
  const _ThreadDepth({required this.depth, required super.child});
  final int depth;
  @override
  bool updateShouldNotify(_ThreadDepth oldWidget) => depth != oldWidget.depth;
}

class _AvatarAnchor extends SingleChildRenderObjectWidget {
  const _AvatarAnchor({required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAvatarAnchor();
}

class _RenderAvatarAnchor extends RenderProxyBox {}

class _ThreadData extends ContainerBoxParentData<RenderBox> {}

class _ThreadLayout extends MultiChildRenderObjectWidget {
  const _ThreadLayout({required this.indent, required this.direction, required this.ink, required this.replyCount, required super.children});
  final double indent;
  final TextDirection direction;
  final Color ink;
  final int replyCount;
  @override
  RenderObject createRenderObject(BuildContext context) => FrostThreadRender(indent, direction, ink, replyCount);
  @override
  void updateRenderObject(BuildContext context, covariant FrostThreadRender renderObject) {
    renderObject
      ..indent = indent
      ..direction = direction
      ..ink = ink
      ..replyCount = replyCount
      ..markNeedsLayout();
  }
}

class FrostThreadRender extends RenderBox with ContainerRenderObjectMixin<RenderBox, _ThreadData>, RenderBoxContainerDefaultsMixin<RenderBox, _ThreadData> {
  FrostThreadRender(this.indent, this.direction, this.ink, this.replyCount);
  double indent;
  TextDirection direction;
  Color ink;
  int replyCount;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ThreadData) child.parentData = _ThreadData();
  }

  @override
  void performLayout() {
    var y = 0.0;
    var index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final inset = index++ == 0 ? 0.0 : math.min(indent, constraints.maxWidth);
      child.layout(
        BoxConstraints(maxWidth: math.max(0, constraints.maxWidth - inset), minWidth: math.max(0, constraints.maxWidth - inset)),
        parentUsesSize: true,
      );
      final data = child.parentData! as _ThreadData;
      data.offset = Offset(direction == TextDirection.rtl ? 0 : inset, y);
      y += child.size.height;
      child = data.nextSibling;
    }
    size = constraints.constrain(Size(constraints.maxWidth, y));
  }

  _RenderAvatarAnchor? _avatar(RenderObject root) {
    if (root is _RenderAvatarAnchor) return root;
    _RenderAvatarAnchor? result;
    root.visitChildren((child) => result ??= _avatar(child));
    return result;
  }

  /// Actual connection geometry, also available to internal render tests.
  List<Path> get connections {
    final paths = <Path>[];
    final parent = firstChild == null ? null : _avatar(firstChild!);
    if (parent == null || replyCount == 0) return paths;
    final rect = MatrixUtils.transformRect(parent.getTransformTo(this), Offset.zero & parent.size);
    final x = rect.center.dx;
    final start = rect.bottom + _connectionGap;
    final targets = <(double, double)>[];
    RenderBox? child = childAfter(firstChild!);
    for (var index = 0; index < replyCount && child != null; index++) {
      final avatar = _avatar(child);
      if (avatar != null && child.size.height > 0) {
        final childRect = MatrixUtils.transformRect(avatar.getTransformTo(this), Offset.zero & avatar.size);
        final data = child.parentData! as _ThreadData;
        final y = math.min(childRect.center.dy, data.offset.dy + child.size.height);
        final end = direction == TextDirection.rtl ? childRect.right + _connectionGap : childRect.left - _connectionGap;
        targets.add((end, y));
      }
      child = childAfter(child);
    }
    if (targets.isEmpty || targets.last.$2 <= start) return paths;
    paths.add(
      Path()
        ..moveTo(x, start)
        ..lineTo(x, targets.last.$2 - (indent == 0 ? 0 : _bendRadius)),
    );
    if (indent > 0) {
      final sign = direction == TextDirection.rtl ? -1.0 : 1.0;
      for (final (end, y) in targets) {
        if (y <= start) continue;
        final radius = math.min(_bendRadius, (end - x).abs());
        paths.add(
          Path()
            ..moveTo(x, math.max(start, y - radius))
            ..quadraticBezierTo(x, y, x + sign * radius, y)
            ..lineTo(end, y),
        );
      }
    }
    return paths;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    final paint = Paint()
      ..color = ink
      ..strokeWidth = _lineWidth
      ..style = PaintingStyle.stroke;
    for (final path in connections) {
      canvas.drawPath(path, paint);
    }
    canvas.restore();
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
