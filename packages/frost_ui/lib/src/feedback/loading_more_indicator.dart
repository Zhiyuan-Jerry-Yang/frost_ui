import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../primitives/text.dart';
import 'compact_message.dart';
import 'error_action_button.dart';
import 'error_content.dart';
import 'list_source.dart';
import 'refresh_dots.dart';

// One stable footer row; no extra spacing is appended below it.
const _footerExtent = 56.0;

/// A full-width source-owned footer, reserved whenever a next page exists.
/// Existing content is never dimmed and next pages never insert skeleton cards.
class FrostLoadingMoreIndicator<T> extends StatelessWidget {
  const FrostLoadingMoreIndicator({required this.source, super.key});
  final FrostListSource<T> source;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: source,
    builder: (context, _) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _footerExtent),
        child: Center(
          child: switch (source.lastError) {
            final error? => FrostPagedError(source: source, placement: FrostPagedErrorPlacement.footer, key: ValueKey((source, error))),
            null when source.hasMore => const FrostRefreshDots(),
            _ => FrostText(FrostScope.labelsOf(context).noMoreItems, role: FrostTextRole.footnote, tone: FrostTextTone.secondary),
          },
        ),
      );
    },
  );
}

/// Internal shared error presentation for page and retained-content failures.
enum FrostPagedErrorPlacement { page, footer }

class FrostPagedError extends StatefulWidget {
  const FrostPagedError({required this.source, required this.placement, super.key});
  final FrostListSource<Object?> source;
  final FrostPagedErrorPlacement placement;
  @override
  State<FrostPagedError> createState() => _PagedErrorState();
}

class _PagedErrorState extends State<FrostPagedError> {
  Timer? _timer;
  int get _seconds => math.max(0, ((widget.source.retryAt?.difference(DateTime.now()).inMilliseconds ?? 0) / 1000).ceil());
  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(FrostPagedError oldWidget) {
    super.didUpdateWidget(oldWidget);
    _start();
  }

  void _start() {
    _timer?.cancel();
    if (_seconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {});
        if (_seconds == 0) timer.cancel();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context);
    final error = widget.source.lastError;
    final label = _seconds > 0 ? labels.retryAfter(_seconds) : labels.retry;
    final VoidCallback? retry = widget.source.canRetry && !widget.source.busy ? () => widget.source.errorRefresh() : null;
    if (widget.placement == FrostPagedErrorPlacement.page) {
      return FrostErrorTitleScope(
        title: labels.loadFailed,
        child: error == null
            ? FrostErrorContent(message: labels.loadFailed, onRetry: retry, retryLabel: label)
            : FrostErrorContent.fromError(error: error, onRetry: retry, retryLabel: label),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: FrostGap.related),
      child: _FooterErrorLayout(
        direction: Directionality.of(context),
        message: error == null ? FrostText(labels.loadFailed, role: FrostTextRole.footnote) : FrostCompactMessage.error(error: error),
        actions: Wrap(
          alignment: WrapAlignment.end,
          spacing: FrostGap.related,
          runSpacing: FrostGap.related,
          children: [
            if (error != null && FrostScope.errorsOf(context).action?.call(context, error) != null)
              FrostErrorActionButton(error: error, onResolved: retry, size: FrostControlSize.compact),
            FrostButton(label: label, onPressed: retry, size: FrostControlSize.compact),
          ],
        ),
      ),
    );
  }
}

// Keep the ordinary footer's message/actions on one row. Reflow only when the
// measured minimum message width and actual action group cannot fit together.
// Both children stay mounted, preserving disclosure and in-flight recovery.
class _FooterErrorLayout extends MultiChildRenderObjectWidget {
  _FooterErrorLayout({required this.direction, required Widget message, required Widget actions}) : super(children: [message, actions]);
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFooterError(direction);
  @override
  void updateRenderObject(BuildContext context, _RenderFooterError renderObject) => renderObject.direction = direction;
}

class _FooterData extends ContainerBoxParentData<RenderBox> {}

class _RenderFooterError extends RenderBox with ContainerRenderObjectMixin<RenderBox, _FooterData>, RenderBoxContainerDefaultsMixin<RenderBox, _FooterData> {
  _RenderFooterError(this._direction);
  TextDirection _direction;
  set direction(TextDirection value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FooterData) child.parentData = _FooterData();
  }

  @override
  void performLayout() {
    final message = firstChild!, actions = lastChild!;
    actions.layout(BoxConstraints(maxWidth: constraints.maxWidth), parentUsesSize: true);
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : message.getMaxIntrinsicWidth(double.infinity) + FrostGap.related + actions.size.width;
    final below = message.getMinIntrinsicWidth(double.infinity) + FrostGap.related + actions.size.width > width;
    message.layout(BoxConstraints(maxWidth: math.max(0, width - (below ? 0 : actions.size.width + FrostGap.related))), parentUsesSize: true);
    final height = below ? message.size.height + FrostGap.related + actions.size.height : math.max(message.size.height, actions.size.height);
    size = constraints.constrain(Size(width, height));
    void place(RenderBox child, double x, double y) =>
        (child.parentData! as _FooterData).offset = Offset(_direction == TextDirection.ltr ? x : size.width - x - child.size.width, y);
    place(message, 0, below ? 0 : (size.height - message.size.height) / 2);
    place(actions, size.width - actions.size.width, below ? message.size.height + FrostGap.related : (size.height - actions.size.height) / 2);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
