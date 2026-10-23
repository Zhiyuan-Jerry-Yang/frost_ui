import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../overlays/tooltip.dart';
import '../primitives/_path_selection.dart';
import '_button_control.dart';
import '_button_types.dart';
import '_field_frame.dart';
import '_field_layout.dart';
import 'form.dart';

// The ellipsis replaces only presentation; selection always copies the path.
const frostPathEllipsis = '…';

/// A readonly, selectable path. Selection and copying treat it as one complete
/// value, even when its displayed middle is elided. Choosing/revealing remains
/// app-owned; asynchronous failures are reported without inventing a message.
class FrostPathField extends StatefulWidget {
  const FrostPathField({required this.path, required this.label, this.onChoose, this.onReveal, this.placeholder, this.help, this.error, super.key});
  final String? path;
  final String label;
  final Future<void> Function()? onChoose;
  final VoidCallback? onReveal;
  final String? placeholder, help, error;
  @override
  State<FrostPathField> createState() => _PathFieldState();
}

class _PathFieldState extends State<FrostPathField> {
  final _chooseFocus = FocusNode(), _textFocus = FocusNode();
  final _layout = FrostLayoutIdentity();
  late final _selection = FrostPathSelection(() => widget.path ?? '');
  bool _loading = false;
  @override
  void dispose() {
    _chooseFocus.dispose();
    _textFocus.dispose();
    _layout.dispose();
    _selection.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    if (_loading || widget.onChoose == null || !FrostControlScope.enabledOf(context)) return;
    setState(() => _loading = true);
    try {
      await widget.onChoose!();
    } catch (error, stack) {
      if (mounted) FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'frost_ui'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = FrostControlScope.enabledOf(context), tokens = FrostThemeTokens.of(context), labels = FrostScope.labelsOf(context);
    final size = FrostControlScope.sizeOf(context), style = FrostTypography.of(context).style(FrostTextRole.body).copyWith(color: tokens.textPrimary);
    final path = widget.path, geometry = frostControlGeometry(context, size);
    double textWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final characters = (path ?? widget.placeholder ?? '').characters.toList();
    final minimumText = characters.length <= 2 ? characters.join() : '${characters.first}$frostPathEllipsis${characters.last}';
    final minimumWidth = textWidth(minimumText) + frostFieldInset(size) * 2;
    final actions = Wrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: FrostGap.related,
      runSpacing: FrostGap.related,
      children: [
        FrostButtonControl(
          label: labels.choose,
          focusNode: _chooseFocus,
          size: FrostControlSize.compact,
          onPressed: enabled && widget.onChoose != null ? _choose : null,
          loading: _loading,
          wrapsLabel: true,
          truncates: false,
        ),
        if (path != null && widget.onReveal != null)
          FrostButtonControl(
            label: labels.showInFolder,
            icon: FrostIconSet.of(context).folder,
            iconStyle: FrostIconButtonStyle.plain,
            size: FrostControlSize.compact,
            onPressed: enabled ? widget.onReveal : null,
          ),
      ],
    );
    final field = ListenableBuilder(
      listenable: Listenable.merge([_chooseFocus, _textFocus]),
      builder: (context, _) => FrostFieldFrame(
        size: size,
        enabled: enabled,
        focused: _chooseFocus.hasFocus || _textFocus.hasFocus,
        invalid: widget.error != null,
        child: LayoutBuilder(
          builder: (context, constraints) {
            var displayed = path ?? widget.placeholder ?? '';
            if (path != null && textWidth(path) > constraints.maxWidth && characters.length > 2) {
              String presentation(int keep) {
                final leading = (keep / 2).ceil(), trailing = keep ~/ 2;
                return '${characters.take(leading).join()}$frostPathEllipsis${characters.skip(characters.length - trailing).join()}';
              }

              var lower = 2, upper = characters.length - 1;
              displayed = presentation(lower);
              while (lower <= upper) {
                final middle = (lower + upper) ~/ 2, candidate = presentation((lower + upper) ~/ 2);
                if (textWidth(candidate) <= constraints.maxWidth) {
                  displayed = candidate;
                  lower = middle + 1;
                } else {
                  upper = middle - 1;
                }
              }
            }
            final text = FrostSkeletonText(
              child: Text(
                displayed,
                style: path == null ? style.copyWith(color: tokens.textTertiary) : style,
                maxLines: 1,
                softWrap: false,
                semanticsLabel: path ?? widget.placeholder,
              ),
            );
            Widget content = path == null
                ? text
                : SelectionArea(
                    focusNode: _textFocus,
                    child: SelectionContainer(delegate: _selection, child: text),
                  );
            if (path != null) content = FrostTooltip(message: path, child: content);
            return Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: geometry.verticalInset),
                child: content,
              ),
            );
          },
        ),
      ),
    );
    return FrostFormFieldRegistration(
      focusOf: () => _chooseFocus,
      enabled: enabled && widget.onChoose != null && !_loading,
      error: widget.error,
      child: FrostFieldLayout(
        label: widget.label,
        help: widget.help,
        error: widget.error,
        enabled: enabled,
        child: FrostMotionSize(
          duration: FrostMotion.duration(context, FrostMotion.layoutFade),
          alignment: AlignmentDirectional.topStart,
          child: FrostLayoutCrossfade(
            layoutIdentity: _layout,
            child: _PathLayout(
              minimumFieldWidth: minimumWidth,
              actionCount: actions.children.length,
              identity: _layout,
              direction: Directionality.of(context),
              children: [field, actions],
            ),
          ),
        ),
      ),
    );
  }
}

class _PathData extends ContainerBoxParentData<RenderBox> {}

class _PathLayout extends MultiChildRenderObjectWidget {
  const _PathLayout({required this.minimumFieldWidth, required this.actionCount, required this.identity, required this.direction, required super.children});
  final double minimumFieldWidth;
  final int actionCount;
  final FrostLayoutIdentity identity;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPath(this);
  @override
  void updateRenderObject(BuildContext context, _RenderPath renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderPath extends RenderBox with ContainerRenderObjectMixin<RenderBox, _PathData>, RenderBoxContainerDefaultsMixin<RenderBox, _PathData> {
  _RenderPath(this.config);
  _PathLayout config;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _PathData) child.parentData = _PathData();
  }

  @override
  void performLayout() {
    final actions = lastChild!, field = firstChild!;
    // RenderWrap's max intrinsic width sums children but omits its spacing.
    final naturalActions = actions.getMaxIntrinsicWidth(double.infinity) + FrostGap.related * math.max(0, config.actionCount - 1);
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : config.minimumFieldWidth + FrostGap.related + naturalActions;
    final below = width < config.minimumFieldWidth + FrostGap.related + naturalActions;
    config.identity.update(below, viewport: constraints);
    actions.layout(BoxConstraints(maxWidth: below ? width : naturalActions), parentUsesSize: true);
    final fieldWidth = below ? width : math.max(0.0, width - FrostGap.related - actions.size.width);
    field.layout(BoxConstraints.tightFor(width: fieldWidth), parentUsesSize: true);
    final height = below ? field.size.height + FrostGap.related + actions.size.height : math.max(field.size.height, actions.size.height);
    size = constraints.constrain(Size(width, height));
    final rtl = config.direction == TextDirection.rtl;
    (field.parentData! as _PathData).offset = Offset(rtl ? width - fieldWidth : 0, below ? 0 : (height - field.size.height) / 2);
    (actions.parentData! as _PathData).offset = Offset(
      rtl ? 0 : width - actions.size.width,
      below ? field.size.height + FrostGap.related : (height - actions.size.height) / 2,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
