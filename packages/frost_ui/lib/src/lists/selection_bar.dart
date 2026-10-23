import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../controls/_button_control.dart';
import '../controls/buttons.dart';
import '../foundation/density.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/content_viewport.dart';
import '../motion/_material_reveal.dart';
import '../motion/rolling_text.dart';
import '../primitives/divider.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';
import 'selection.dart';

@immutable
class FrostSelectionAction {
  const FrostSelectionAction({required this.label, required this.icon, required this.onPressed, this.destructive = false});
  final String label;
  final FrostIconData icon;
  final VoidCallback? onPressed;
  final bool destructive;
}

/// A full-width bottom slot which occupies its actual animated height.
/// Place after an Expanded scroll view in a Column, keeping the scroll view's
/// key/controller stable. The shrinking viewport preserves its scroll offset
/// and lets its final item scroll above the bar. In a Stack, the caller must
/// reserve equivalent space; this widget does not report height after layout.
class FrostSelectionBar<T> extends StatelessWidget {
  const FrostSelectionBar({required this.selection, required this.allItems, this.actions = const [], super.key});
  final FrostSelection<T> selection;
  final Iterable<T> allItems;
  final List<FrostSelectionAction> actions;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: selection,
    builder: (context, _) {
      final labels = FrostScope.labelsOf(context);
      final all = allItems.toSet();
      return _SelectionBarVisibility(
        visible: selection.active,
        child: Focus(
          canRequestFocus: false,
          onKeyEvent: (_, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape && selection.active) {
              selection.exit();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: FrostSurface(
              role: FrostSurfaceRole.chrome,
              borderRadius: BorderRadius.zero,
              edge: FrostSurfaceEdge.none,
              elevated: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FrostDivider(),
                  SafeArea(
                    top: false,
                    child: FrostContentColumn(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: FrostGap.related),
                        child: _BarFlow(
                          direction: Directionality.of(context),
                          children: [
                            Wrap(
                              spacing: FrostGap.group,
                              runSpacing: FrostGap.related,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _SelectionCount(labels.selectedCount(selection.selected.length)),
                                FrostButtonControl(
                                  label: labels.selectAll,
                                  variant: FrostButtonVariant.plain,
                                  // This is a neighbour of the count, not a keyline
                                  // edge: keep its visible label exactly one group gap away.
                                  geometry: FrostButtonGeometry(
                                    horizontalInset: 0,
                                    verticalInset: 0,
                                    minimumWidth: FrostDensity.of(context).targetHeight,
                                    alignment: MainAxisAlignment.start,
                                  ),
                                  onPressed: all.every(selection.isSelected) ? null : () => selection.selectAll(all),
                                ),
                              ],
                            ),
                            Wrap(
                              spacing: FrostGap.group,
                              runSpacing: FrostGap.related,
                              alignment: WrapAlignment.end,
                              children: [
                                for (final action in actions)
                                  FrostButton(
                                    label: action.label,
                                    icon: action.icon,
                                    variant: FrostButtonVariant.plain,
                                    role: action.destructive ? FrostButtonRole.destructive : FrostButtonRole.normal,
                                    onPressed: selection.selected.isEmpty ? null : action.onPressed,
                                  ),
                                FrostButton(label: labels.done, variant: FrostButtonVariant.plain, onPressed: selection.exit),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _SelectionBarVisibility extends StatefulWidget {
  const _SelectionBarVisibility({required this.visible, required this.child});
  final bool visible;
  final Widget child;
  @override
  State<_SelectionBarVisibility> createState() => _SelectionBarVisibilityState();
}

class _SelectionBarVisibilityState extends State<_SelectionBarVisibility> with SingleTickerProviderStateMixin {
  late final _progress = AnimationController.unbounded(vsync: this, value: widget.visible ? 1 : 0);
  final _glass = FrostRevealHandle();
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
    if (MediaQuery.disableAnimationsOf(context)) {
      _progress.animateTo(widget.visible ? 1 : 0, duration: FrostMotion.reducedFade);
    } else {
      FrostMotion.springTo(context, _progress, widget.visible ? 1 : 0, FrostMotion.standard);
    }
  }

  @override
  void didUpdateWidget(_SelectionBarVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) _animate();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _progress,
    child: widget.child,
    builder: (context, child) {
      final progress = _progress.value.clamp(0.0, 1.0);
      if (progress == 0 && !widget.visible) return const SizedBox.shrink();
      final reduced = MediaQuery.disableAnimationsOf(context);
      return ClipRect(
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: reduced ? 1 : progress,
          child: FractionalTranslation(
            translation: Offset(0, reduced ? 0 : 1 - progress),
            child: FrostMaterialReveal(
              handle: _glass,
              opacity: progress,
              child: IgnorePointer(
                ignoring: !widget.visible,
                child: ExcludeFocus(
                  excluding: !widget.visible,
                  child: ExcludeSemantics(excluding: !widget.visible, child: child!),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Two measured groups flow as a whole on the first layout, then wrap inside
/// their own available widths. No post-frame size callback or duplicate tree.
class _BarFlow extends MultiChildRenderObjectWidget {
  const _BarFlow({required this.direction, required super.children});
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderBarFlow(direction);
  @override
  void updateRenderObject(BuildContext context, _RenderBarFlow renderObject) {
    renderObject.direction = direction;
    renderObject.markNeedsLayout();
  }
}

class _BarParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderBarFlow extends RenderBox with ContainerRenderObjectMixin<RenderBox, _BarParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _BarParentData> {
  _RenderBarFlow(this.direction);
  TextDirection direction;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BarParentData) child.parentData = _BarParentData();
  }

  @override
  void performLayout() {
    final start = firstChild!, end = lastChild!;
    final width = constraints.maxWidth;
    final inline = start.getMaxIntrinsicWidth(double.infinity) + end.getMaxIntrinsicWidth(double.infinity) + FrostGap.related <= width;
    start.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    end.layout(BoxConstraints(maxWidth: inline ? math.max(0, width - start.size.width - FrostGap.related) : width), parentUsesSize: true);
    size = constraints.constrain(Size(width, inline ? math.max(start.size.height, end.size.height) : start.size.height + FrostGap.related + end.size.height));
    final startX = direction == TextDirection.ltr ? 0.0 : width - start.size.width;
    final endX = direction == TextDirection.ltr ? width - end.size.width : 0.0;
    (start.parentData! as _BarParentData).offset = Offset(startX, inline ? (size.height - start.size.height) / 2 : 0);
    (end.parentData! as _BarParentData).offset = Offset(endX, inline ? (size.height - end.size.height) / 2 : start.size.height + FrostGap.related);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

/// Counts roll when they fit; unusually long translations wrap at full size.
class _SelectionCount extends StatelessWidget {
  const _SelectionCount(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    label: text,
    excludeSemantics: true,
    child: _CountLayout(
      children: [
        FrostRollingText(
          text,
          style: FrostTypography.of(context).style(FrostTextRole.callout, numeric: true).copyWith(color: FrostThemeTokens.of(context).textSecondary),
        ),
        FrostText(text, role: FrostTextRole.callout, tone: FrostTextTone.secondary, numeric: true),
      ],
    ),
  );
}

class _CountLayout extends MultiChildRenderObjectWidget {
  const _CountLayout({required super.children});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCount();
}

class _RenderCount extends RenderBox with ContainerRenderObjectMixin<RenderBox, _BarParentData> {
  RenderBox? _visible;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _BarParentData) child.parentData = _BarParentData();
  }

  RenderBox _choose(BoxConstraints limits) => firstChild!.getMaxIntrinsicWidth(double.infinity) <= limits.maxWidth ? firstChild! : lastChild!;
  @override
  void performLayout() {
    _visible = _choose(constraints)..layout(constraints, parentUsesSize: true);
    size = constraints.constrain(_visible!.size);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.constrain(_choose(constraints).getDryLayout(constraints));
  @override
  double computeMaxIntrinsicWidth(double height) => firstChild!.getMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicWidth(double height) => lastChild!.getMinIntrinsicWidth(height);
  @override
  double computeMaxIntrinsicHeight(double width) => getDryLayout(BoxConstraints(maxWidth: width)).height;
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  void paint(PaintingContext context, Offset offset) => context.paintChild(_visible!, offset);
  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {}
}
