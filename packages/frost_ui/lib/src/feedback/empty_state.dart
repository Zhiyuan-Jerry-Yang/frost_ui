import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/icon.dart';
import '../primitives/text.dart';

// Empty states stay readable in a compact column, with a quiet 28-point icon.
const _emptyMaximumWidth = 360.0, _emptyIconSize = 28.0;
const _emptyActionGap = 16.0;
// Anchor summaries in the upper quarter, independently of their details.
const _stateTopFraction = .25;

/// Page-owned empty content. The summary starts a quarter down finite height;
/// details expand below it without moving the summary. All content can scroll
/// when it needs more room, starting at the top in a short viewport.
class FrostEmptyState extends StatelessWidget {
  const FrostEmptyState({this.icon, required this.title, this.message, this.actionLabel, this.onAction, this.details, super.key})
    : assert(actionLabel != null || onAction == null, 'An action callback requires its localized label.');

  /// Search-empty content uses app-localized labels and the semantic search icon.
  factory FrostEmptyState.search({required String query, required VoidCallback onClear, Key? key}) =>
      _SearchEmptyState(query: query, onClear: onClear, key: key);
  final FrostIconData? icon;
  final String title;
  final String? message, actionLabel;
  final VoidCallback? onAction;
  final Widget? details;
  @override
  Widget build(BuildContext context) {
    return FrostStateContent(
      icon: icon,
      title: title,
      message: message,
      details: details,
      actions: actionLabel == null ? null : FrostButton(label: actionLabel!, onPressed: onAction),
    );
  }
}

// Shared full-page state layout, intentionally not exported as an arbitrary
// public styling slot. Error and empty content use the same anchor and scroll.
class FrostStateContent extends StatelessWidget {
  const FrostStateContent({this.icon, required this.title, this.message, this.actions, this.details, super.key});
  final FrostIconData? icon;
  final String title;
  final String? message;
  final Widget? actions, details;
  @override
  Widget build(BuildContext context) {
    final layout = _EmptyLayout();
    final body = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _emptyMaximumWidth),
      child: _EmptyBody(
        layout: layout,
        summary: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon case final icon?) ...[
              FrostIcon(icon, size: _emptyIconSize, color: FrostEmptyIconInk.maybeOf(context) ?? FrostThemeTokens.of(context).textTertiary),
              const SizedBox(height: FrostGap.group),
            ],
            FrostText(title, role: FrostTextRole.title2, tone: FrostTextTone.primary, textAlign: TextAlign.center),
            if (message case final text?) ...[
              const SizedBox(height: FrostGap.related),
              FrostText(text, role: FrostTextRole.callout, tone: FrostTextTone.secondary, textAlign: TextAlign.center),
            ],
            if (actions case final actions?) ...[const SizedBox(height: _emptyActionGap), actions],
          ],
        ),
        details: details == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.only(top: FrostGap.group),
                child: details,
              ),
      ),
    );
    return _CenteredScroll(
      layout: layout,
      child: SingleChildScrollView(primary: false, child: Center(child: body)),
    );
  }
}

class _SearchEmptyState extends FrostEmptyState {
  const _SearchEmptyState({required this.query, required this.onClear, super.key}) : super(title: '');
  final String query;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context);
    return FrostEmptyState(icon: FrostIconSet.of(context).search, title: labels.noResults(query), actionLabel: labels.clearSearch, onAction: onClear);
  }
}

// The viewport supplies its height before laying out the scroll content. Keeping
// the anchor space inside that content lets an explicit scroll use the whole
// viewport, while details changing height never recenter the summary.
class _EmptyLayout {
  double viewportHeight = 0;
  _RenderEmptyBody? body;
}

class _CenteredScroll extends SingleChildRenderObjectWidget {
  const _CenteredScroll({required this.layout, required super.child});
  final _EmptyLayout layout;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCenteredScroll(layout);
  @override
  void updateRenderObject(BuildContext context, _RenderCenteredScroll renderObject) => renderObject.anchorLayout = layout;
}

class _RenderCenteredScroll extends RenderShiftedBox {
  _RenderCenteredScroll(this._layout) : super(null);
  _EmptyLayout _layout;
  set anchorLayout(_EmptyLayout value) {
    _layout = value;
    markNeedsLayout();
  }

  // SliverFillRemaining must measure the summary, not expanded details. Otherwise
  // its new extent becomes the next anchor viewport and moves the summary.
  @override
  double computeMinIntrinsicHeight(double width) => _layout.body?.summary.getMinIntrinsicHeight(width.clamp(0, _emptyMaximumWidth)) ?? 0;
  @override
  double computeMaxIntrinsicHeight(double width) => _layout.body?.summary.getMaxIntrinsicHeight(width.clamp(0, _emptyMaximumWidth)) ?? 0;
  @override
  void performLayout() {
    final height = constraints.hasBoundedHeight ? constraints.maxHeight : 0.0;
    if (_layout.viewportHeight != height) {
      invokeLayoutCallback<BoxConstraints>((_) {
        _layout.viewportHeight = height;
        _layout.body?.markNeedsLayout();
      });
    }
    child!.layout(BoxConstraints(minHeight: height, maxWidth: constraints.maxWidth, maxHeight: constraints.maxHeight), parentUsesSize: true);
    size = constraints.constrain(
      Size(constraints.hasBoundedWidth ? constraints.maxWidth : child!.size.width, constraints.hasBoundedHeight ? constraints.maxHeight : child!.size.height),
    );
    (child!.parentData! as BoxParentData).offset = Offset((size.width - child!.size.width) / 2, 0);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final measured = child!.getDryLayout(BoxConstraints(maxWidth: constraints.maxWidth, maxHeight: constraints.maxHeight));
    return constraints.constrain(
      Size(constraints.hasBoundedWidth ? constraints.maxWidth : measured.width, constraints.hasBoundedHeight ? constraints.maxHeight : measured.height),
    );
  }
}

class _EmptyBody extends MultiChildRenderObjectWidget {
  _EmptyBody({required this.layout, required Widget summary, required Widget details}) : super(children: [summary, details]);
  final _EmptyLayout layout;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEmptyBody(layout);
  @override
  void updateRenderObject(BuildContext context, _RenderEmptyBody renderObject) => renderObject.anchorLayout = layout;
}

class _EmptyParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEmptyBody extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, ContainerBoxParentData<RenderBox>>,
        RenderBoxContainerDefaultsMixin<RenderBox, ContainerBoxParentData<RenderBox>> {
  _RenderEmptyBody(this._layout) {
    _layout.body = this;
  }
  _EmptyLayout _layout;
  RenderBox get summary => firstChild!;
  set anchorLayout(_EmptyLayout value) {
    _layout.body = null;
    _layout = value..body = this;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EmptyParentData) child.parentData = _EmptyParentData();
  }

  @override
  double computeMinIntrinsicWidth(double height) => math.max(summary.getMinIntrinsicWidth(height), lastChild!.getMinIntrinsicWidth(height));
  @override
  double computeMaxIntrinsicWidth(double height) => math.max(summary.getMaxIntrinsicWidth(height), lastChild!.getMaxIntrinsicWidth(height));
  @override
  double computeMinIntrinsicHeight(double width) => summary.getMinIntrinsicHeight(width) + lastChild!.getMinIntrinsicHeight(width);
  @override
  double computeMaxIntrinsicHeight(double width) => summary.getMaxIntrinsicHeight(width) + lastChild!.getMaxIntrinsicHeight(width);
  double _top(double summaryHeight) => math.min(_layout.viewportHeight * _stateTopFraction, math.max(0, _layout.viewportHeight - summaryHeight));
  @override
  void performLayout() {
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    summary.layout(loose, parentUsesSize: true);
    lastChild!.layout(loose.tighten(width: constraints.hasBoundedWidth ? constraints.maxWidth : null), parentUsesSize: true);
    final top = _top(summary.size.height);
    size = constraints.constrain(Size(math.max(summary.size.width, lastChild!.size.width), top + summary.size.height + lastChild!.size.height));
    (summary.parentData! as BoxParentData).offset = Offset((size.width - summary.size.width) / 2, top);
    (lastChild!.parentData! as BoxParentData).offset = Offset((size.width - lastChild!.size.width) / 2, top + summary.size.height);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final loose = BoxConstraints(maxWidth: constraints.maxWidth);
    final main = summary.getDryLayout(loose),
        details = lastChild!.getDryLayout(loose.tighten(width: constraints.hasBoundedWidth ? constraints.maxWidth : null));
    return constraints.constrain(Size(math.max(main.width, details.width), _top(main.height) + main.height + details.height));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

/// Internal semantic ink override for error content, not a public style slot.
class FrostEmptyIconInk extends InheritedWidget {
  const FrostEmptyIconInk({required this.color, required super.child, super.key});
  final Color color;
  static Color? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostEmptyIconInk>()?.color;
  @override
  bool updateShouldNotify(FrostEmptyIconInk oldWidget) => color != oldWidget.color;
}
