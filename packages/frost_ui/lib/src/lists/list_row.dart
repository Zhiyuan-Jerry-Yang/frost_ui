import 'dart:math' as math;
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../controls/_picker_row_scope.dart';
import '../controls/checkbox.dart';
import '../controls/switch.dart';
import '../display/_status_metrics.dart';
import '../display/status_dot.dart';
import '../feedback/_skeleton_geometry.dart';
import '../feedback/skeleton.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/_row_metrics.dart';
import '../foundation/control_scope.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_layout_identity.dart';
import '../motion/_material_reveal.dart';
import '../motion/_user_selection_draw.dart';
import '../motion/layout_crossfade.dart';
import '../motion/spring.dart';
import '../overlays/_additional_menu_entries.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/path_text.dart';
import '../primitives/presence.dart';
import '_inline_row_text.dart';
import '_row_content.dart';
import '_row_layout.dart';
import '_row_scope.dart';
import '_selection_presentation.dart';

// Text blocks keep their base breathing room; secondary lines share this gap.
const _rowTextGap = 2.0;
const _rowDisabledOpacity = .38;

enum FrostRowAccessory { none, chevron, external }

/// The subtitle stays a string; a path only changes wrapping and original-value selection.
enum FrostRowSubtitleKind { text, path }

/// A readable row. Values move below the text when their actual widths cannot
/// share one line; labels and values never truncate at larger text sizes.
class FrostListRow extends StatefulWidget {
  /// Explicit content determines bones only; semantics use the loading label.
  factory FrostListRow.skeleton({required String title, required bool icon, required String? subtitle, required String? value}) =>
      _SkeletonListRow(icon, title: title, subtitle: subtitle, value: value);
  const FrostListRow({
    required this.title,
    this.subtitle,
    this.subtitleStatus,
    this.subtitleKind = FrostRowSubtitleKind.text,
    this.inlineSubtitle = false,
    this.selected = false,
    this.icon,
    this.leading,
    this.value,
    this.accessory = FrostRowAccessory.none,
    this.trailing,
    this.onPressed,
    this.destructive = false,
    this.enabled = true,
    this.contextMenu = const [],
    super.key,
  }) : assert(subtitleKind != FrostRowSubtitleKind.path || (!inlineSubtitle && subtitleStatus == null)),
       assert(icon == null || leading == null),
       assert(subtitleStatus == null || (subtitle != null && !inlineSubtitle)),
       _toggle = null,
       _onChanged = null,
       _checked = null;
  const FrostListRow.toggle({
    required this.title,
    this.subtitle,
    this.subtitleStatus,
    this.subtitleKind = FrostRowSubtitleKind.text,
    this.inlineSubtitle = false,
    this.selected = false,
    this.icon,
    required bool value,
    required ValueChanged<bool>? onChanged,
    super.key,
  }) : assert(subtitleKind != FrostRowSubtitleKind.path || (!inlineSubtitle && subtitleStatus == null)),
       assert(subtitleStatus == null || (subtitle != null && !inlineSubtitle)),
       leading = null,
       value = null,
       accessory = FrostRowAccessory.none,
       trailing = null,
       onPressed = null,
       destructive = false,
       enabled = onChanged != null,
       contextMenu = const [],
       _toggle = value,
       _onChanged = onChanged,
       _checked = null;
  const FrostListRow.check({
    required this.title,
    this.subtitle,
    this.subtitleStatus,
    this.subtitleKind = FrostRowSubtitleKind.text,
    this.inlineSubtitle = false,
    this.selected = false,
    this.icon,
    required bool checked,
    required this.onPressed,
    super.key,
  }) : assert(subtitleKind != FrostRowSubtitleKind.path || (!inlineSubtitle && subtitleStatus == null)),
       assert(subtitleStatus == null || (subtitle != null && !inlineSubtitle)),
       leading = null,
       value = null,
       accessory = FrostRowAccessory.none,
       trailing = null,
       destructive = false,
       enabled = onPressed != null,
       contextMenu = const [],
       _toggle = null,
       _onChanged = null,
       // Keep the public argument named checked; the storage is private.
       // ignore: prefer_initializing_formals
       _checked = checked;
  final String title;
  final String? subtitle, value;

  /// An optional semantic status dot before the ordinary subtitle. The subtitle
  /// remains the sole text and accessibility value; no arbitrary content slot.
  final FrostStatusTone? subtitleStatus;
  final FrostRowSubtitleKind subtitleKind;

  /// Places the subtitle after the full title on the same baseline. The
  /// subtitle ellipsizes in the remaining space and never creates a second
  /// line; only the title can wrap. Trailing metadata keeps its inline place.
  /// Accessibility retains the complete subtitle even when it is truncated.
  final bool inlineSubtitle;

  /// Highlights this row without entering checkmark or checkbox selection mode.
  /// Shares the task-row fill, ink and transition; activation is unchanged.
  final bool selected;
  final FrostIconData? icon;
  final Widget? leading, trailing;
  final FrostRowAccessory accessory;
  final VoidCallback? onPressed;
  final bool destructive, enabled;
  final List<FrostMenuEntry> contextMenu;
  final bool? _toggle, _checked;
  final ValueChanged<bool>? _onChanged;
  @override
  State<FrostListRow> createState() => _FrostListRowState();
}

class _SkeletonListRow extends FrostListRow {
  const _SkeletonListRow(this._icon, {required super.title, required super.subtitle, required super.value});
  final bool _icon;
  @override
  State<FrostListRow> createState() => _SkeletonRowState();
}

class _SkeletonRowState extends State<_SkeletonListRow> {
  @override
  Widget build(BuildContext context) => FrostListRow(
    title: widget.title,
    subtitle: widget.subtitle,
    value: widget.value,
    icon: widget._icon ? FrostIconSet.of(context).empty : null,
  ).frostSkeleton(true);
}

class _FrostListRowState extends State<FrostListRow> {
  final _focus = FocusNode();
  final _layout = FrostLayoutIdentity();
  FrostListItemHandle? _handle;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindHandle();
  }

  @override
  void didUpdateWidget(FrostListRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindHandle();
  }

  void _bindHandle() {
    final handle = FrostListItemScope.of(context)?.handle;
    if (_handle != handle) {
      _handle?.activate = null;
      _handle = handle;
    }
    _handle?.activate = _activate;
  }

  void _activate() {
    if (!widget.enabled || !FrostControlScope.enabledOf(context)) return;
    final multiple = FrostSelectionPresentation.of(context);
    if (multiple != null) {
      multiple.activate(_originalAction);
      return;
    }
    _originalAction();
  }

  void _originalAction() {
    final selection = FrostListItemScope.of(context)?.onSelected;
    if (selection != null) {
      selection();
    } else if (widget._toggle case final value?) {
      widget._onChanged?.call(!value);
    } else {
      widget.onPressed?.call();
    }
  }

  @override
  void dispose() {
    _handle?.activate = null;
    _focus.dispose();
    _layout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && FrostControlScope.enabledOf(context);
    final item = FrostListItemScope.of(context);
    final content = FrostRowContent.of(context);
    final selected = content?.selected ?? widget.selected;
    final multiple = FrostSelectionPresentation.of(context);
    final interactive = enabled && (multiple != null || item?.onSelected != null || widget.onPressed != null || widget._onChanged != null);
    final checked = item?.selected ?? widget._checked;
    final placement = FrostRowPlacement.of(context);
    final inside = FrostKeyline.maybeOf(context)?.insideContainer ?? false;
    final tokens = FrostThemeTokens.of(context);
    final geometry = frostControlGeometry(context, FrostControlSize.regular);
    Widget? cluster;
    if (widget.value != null || widget.trailing != null) {
      cluster = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.value case final value?)
            Flexible(
              child: ExcludeSemantics(
                child: _RowText(value, role: FrostTextRole.body, color: selected ? tokens.selectionInk : tokens.textSecondary),
              ),
            ),
          if (widget.value != null && widget.trailing != null) const SizedBox(width: FrostGap.related),
          if (widget.trailing case final trailing?)
            Flexible(
              child: Semantics(
                container: true,
                child: FrostControlScope(
                  size: FrostControlSize.compact,
                  child: FrostRowTrailingAlignment(
                    enabled: widget.accessory == FrostRowAccessory.none && checked == null && widget._toggle == null,
                    child: trailing,
                  ),
                ),
              ),
            ),
        ],
      );
    }
    final ends = <Widget>[
      if (widget._toggle case final value?)
        ExcludeFocus(
          child: IgnorePointer(
            child: FrostSwitch(value: value, onChanged: (_) {}, semanticLabel: null),
          ),
        ),
      if (widget.accessory != FrostRowAccessory.none)
        FrostIcon(
          widget.accessory == FrostRowAccessory.chevron ? FrostIconSet.of(context).chevronRight : FrostIconSet.of(context).externalLink,
          size: FrostControlSize.compact.iconSize,
          color: selected ? tokens.selectionInk : tokens.textTertiary,
        ),
      if (checked != null)
        SizedBox.square(
          dimension: FrostControlSize.regular.iconSize,
          child: FrostPresence(
            visible: checked,
            child: FrostIcon(FrostIconSet.of(context).check, size: FrostControlSize.regular.iconSize, color: tokens.selectionInk),
          ),
        ),
    ];
    Widget row(BuildContext context) {
      final inset = inside
          ? EdgeInsets.symmetric(horizontal: FrostGap.of(context).rowInset)
          : (item?.viewportInset ?? frostBleedOutsetsOf(context)).resolve(Directionality.of(context));
      final direction = Directionality.of(context);
      // Standalone rows share one rounded surface for selection/hover/press.
      // Contiguous groups alone supply their outer/middle row corner geometry.
      final corners = placement?.corners ?? FrostRadius.borderRadius(FrostRadius.sm);
      final shape = switch (FrostRadius.shape(context, FrostRadius.sm)) {
        RoundedSuperellipseBorder() => RoundedSuperellipseBorder(borderRadius: corners),
        _ => RoundedRectangleBorder(borderRadius: corners),
      };
      final control = FrostClickHighlight(
        highlighted: enabled && (item?.highlighted ?? false),
        child: FrostClickSurface(
          focusNode: FrostRowFocus.of(context) ?? _focus,
          onTap: interactive ? _activate : null,
          onLongPress: enabled ? multiple?.longPress : null,
          customBorder: shape,
          child: FrostMotionSize(
            duration: FrostMotion.duration(context, FrostMotion.layoutFade),
            alignment: AlignmentDirectional.topStart,
            child: FrostLayoutCrossfade(
              layoutIdentity: _layout,
              settleDuration: Duration.zero,
              child: FrostRowLayout(
                identity: _layout,
                // Rich rows do not display subtitle; progress/detail changes must not
                // crossfade their title through this unused fallback string.
                contentIdentity: (
                  widget.title,
                  content == null ? widget.subtitle : null,
                  widget.value,
                  widget.trailing?.key,
                  widget.inlineSubtitle,
                  widget.subtitleKind,
                ),
                keepValueInline: content != null || widget.inlineSubtitle,
                minimumInlineTextWidth: content == null ? 0 : geometry.height - geometry.verticalInset * 2,
                minimumHeight: FrostControlSize.regular.height(context),
                verticalInset: geometry.verticalInset,
                inset: inset,
                direction: direction,
                children: [
                  if (multiple != null)
                    FrostRowSlot(
                      id: FrostRowPart.selection,
                      child: FrostUserSelectionTrigger(
                        trigger: multiple.drawTrigger,
                        child: _SelectionColumn(active: multiple.active, selected: multiple.selected),
                      ),
                    ),
                  if (widget.leading != null || widget.icon != null || item?.reserveIconColumn == true)
                    FrostRowSlot(
                      id: FrostRowPart.leading,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: frostRowIconColumn),
                        child: Align(
                          // The page keyline aligns visible icon ink. Grouped
                          // rows retain the centred shared 28-point icon column.
                          alignment: !inside && FrostKeyline.maybeOf(context) != null && widget.leading == null
                              ? AlignmentDirectional.centerStart
                              : Alignment.center,
                          widthFactor: 1,
                          heightFactor: 1,
                          child:
                              widget.leading ??
                              (widget.icon == null
                                  ? const SizedBox.shrink()
                                  : FrostIcon(
                                      widget.icon!,
                                      size: FrostControlSize.regular.iconSize,
                                      color: selected ? tokens.selectionInk : tokens.textSecondary,
                                    )),
                        ),
                      ),
                    ),
                  FrostRowSlot(
                    id: FrostRowPart.text,
                    child: widget.inlineSubtitle && content == null && widget.subtitle != null
                        ? FrostInlineRowText(
                            key: placement?.textAnchor ?? multiple?.textAnchor,
                            direction: direction,
                            title: _RowText(
                              widget.title,
                              role: FrostTextRole.body,
                              color: selected ? tokens.selectionInk : (widget.destructive ? tokens.negativeInk : tokens.textPrimary),
                            ),
                            subtitle: _RowText(
                              widget.subtitle!,
                              role: FrostTextRole.footnote,
                              color: selected ? tokens.selectionInk : tokens.textSecondary,
                              singleLine: true,
                            ),
                          )
                        : Column(
                            key: placement?.textAnchor ?? multiple?.textAnchor,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _RowText(
                                widget.title,
                                role: FrostTextRole.body,
                                color: selected ? tokens.selectionInk : (widget.destructive ? tokens.negativeInk : tokens.textPrimary),
                              ),
                              if (content != null)
                                content.belowTitle
                              else if (widget.subtitle case final subtitle?) ...[
                                const SizedBox(height: _rowTextGap),
                                if (widget.subtitleKind == FrostRowSubtitleKind.path)
                                  AnimatedDefaultTextStyle(
                                    style: FrostTypography.of(
                                      context,
                                    ).style(FrostTextRole.footnote).copyWith(color: selected ? tokens.selectionInk : tokens.textSecondary),
                                    duration: FrostMotion.duration(context, FrostMotion.hover),
                                    child: FrostPathText(subtitle, role: FrostTextRole.footnote),
                                  )
                                else
                                  _RowSubtitle(subtitle, status: widget.subtitleStatus, color: selected ? tokens.selectionInk : tokens.textSecondary),
                              ],
                            ],
                          ),
                  ),
                  if (cluster != null) FrostRowSlot(id: FrostRowPart.value, includeSemantics: true, child: cluster),
                  if (ends.isNotEmpty)
                    FrostRowSlot(
                      id: FrostRowPart.end,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 0; i < ends.length; i++) ...[if (i > 0) const SizedBox(width: FrostGap.related), ends[i]],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      // Row selection uses the same surface and interaction geometry. Put
      // the fill behind the click surface so hover/press feedback remains live.
      final grouped = placement?.corners != null;
      final selectedControl = AnimatedContainer(
        duration: FrostMotion.duration(context, FrostMotion.hover),
        curve: FrostMotion.hoverCurve,
        decoration: grouped
            ? BoxDecoration(color: tokens.selectionFill.withValues(alpha: selected ? tokens.selectionFill.a : 0))
            : ShapeDecoration(
                color: tokens.selectionFill.withValues(alpha: selected ? tokens.selectionFill.a : 0),
                shape: shape,
              ),
        child: control,
      );
      return grouped ? FrostClickSurfaceVisuals.grouped(child: selectedControl) : selectedControl;
    }

    Widget accessibleRow(BuildContext context) {
      Widget control = row(context);
      control = Semantics(
        label: widget.title,
        value: content?.semanticValue ?? (widget.inlineSubtitle ? [widget.subtitle, widget.value].nonNulls.join(', ') : widget.value ?? widget.subtitle),
        button: interactive,
        toggled: widget._toggle,
        selected: selected,
        checked: multiple?.active == true ? multiple!.selected : (widget._toggle == null ? checked : null),
        enabled: enabled ? (interactive ? true : null) : false,
        onTap: interactive ? _activate : null,
        container: widget.trailing != null,
        explicitChildNodes: widget.trailing != null,
        excludeSemantics: widget.trailing == null,
        child: ExcludeFocus(
          excluding: !enabled,
          child: IgnorePointer(
            ignoring: !enabled,
            child: FrostAnimatedMaterialReveal(
              opacity: enabled ? 1 : _rowDisabledOpacity,
              duration: FrostMotion.duration(context, FrostMotion.hover),
              child: control,
            ),
          ),
        ),
      );
      final entries = [...widget.contextMenu, ...FrostAdditionalMenuEntries.of(context)];
      if (entries.isNotEmpty) control = FrostContextMenuRegion(entries: entries, enabled: enabled, child: control);
      return multiple == null ? control : MetaData(metaData: frostSelectionInputTarget, behavior: HitTestBehavior.translucent, child: control);
    }

    // Put semantics and focus inside the expanded hit box. A scrolling list
    // already expands its viewport and supplies the same granted content inset.
    return FrostPickerRowScope(
      child: inside || item != null
          ? Builder(builder: accessibleRow)
          : FrostBleed(
              amount: FrostGap.of(context).hitInset,
              child: Builder(builder: accessibleRow),
            ),
    );
  }
}

class _RowText extends StatelessWidget {
  const _RowText(this.text, {required this.role, required this.color, this.singleLine = false});
  final bool singleLine;
  final String text;
  final FrostTextRole role;
  final Color color;
  @override
  Widget build(BuildContext context) => AnimatedDefaultTextStyle(
    style: FrostTypography.of(context).style(role, numeric: true).copyWith(color: color),
    duration: FrostMotion.duration(context, FrostMotion.hover),
    curve: FrostMotion.hoverCurve,
    child: FrostSkeletonText(
      child: Text(text, maxLines: singleLine ? 1 : null, overflow: singleLine ? TextOverflow.ellipsis : null),
    ),
  );
}

class _SelectionColumn extends StatelessWidget {
  const _SelectionColumn({required this.active, required this.selected});
  final bool active, selected;
  @override
  Widget build(BuildContext context) {
    final column = Padding(
      padding: const EdgeInsetsDirectional.only(end: FrostGap.related),
      child: SizedBox(
        width: frostRowIconColumn,
        child: Center(
          child: ExcludeFocus(
            child: IgnorePointer(
              child: FrostCheckbox(value: selected, onChanged: (_) {}, semanticLabel: null),
            ),
          ),
        ),
      ),
    );
    if (MediaQuery.disableAnimationsOf(context)) {
      return FrostPresence(visible: active, effect: FrostPresenceEffect.expand, axis: Axis.horizontal, child: column);
    }
    return FrostSpringBuilder(
      value: active ? 1 : 0,
      spring: FrostMotion.standard,
      builder: (_, progress, child) => ClipRect(
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: progress.clamp(0.0, 1.0),
          heightFactor: 1,
          child: Opacity(opacity: progress.clamp(0.0, 1.0), child: child),
        ),
      ),
      child: ExcludeSemantics(excluding: !active, child: column),
    );
  }
}

class _RowSubtitle extends StatelessWidget {
  const _RowSubtitle(this.text, {required this.status, required this.color});
  final String text;
  final FrostStatusTone? status;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final label = _RowText(text, role: FrostTextRole.footnote, color: color);
    if (status == null) return label;
    return _StatusSubtitleLayout(
      text: text,
      style: FrostTypography.of(context).style(FrostTextRole.footnote, numeric: true),
      scaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
      children: [
        FrostStatusDot(tone: status!),
        label,
      ],
    );
  }
}

class _StatusSubtitleData extends ContainerBoxParentData<RenderBox> {}

/// Measures the same wrapped first line before placing the decorative dot.
/// A pre-build unbounded measurement has different leading for multiline text.
class _StatusSubtitleLayout extends MultiChildRenderObjectWidget {
  const _StatusSubtitleLayout({required this.text, required this.style, required this.scaler, required this.direction, required super.children});
  final String text;
  final TextStyle style;
  final TextScaler scaler;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderStatusSubtitle(this);
  @override
  void updateRenderObject(BuildContext context, _RenderStatusSubtitle renderObject) => renderObject.update(this);
}

class _RenderStatusSubtitle extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _StatusSubtitleData>, RenderBoxContainerDefaultsMixin<RenderBox, _StatusSubtitleData> {
  _RenderStatusSubtitle(this.spec);
  _StatusSubtitleLayout spec;
  double get start => frostStatusDotExtent + FrostGap.related;
  void update(_StatusSubtitleLayout value) {
    spec = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _StatusSubtitleData) child.parentData = _StatusSubtitleData();
  }

  @override
  double computeMaxIntrinsicWidth(double height) => start + lastChild!.getMaxIntrinsicWidth(height);
  @override
  double computeMinIntrinsicWidth(double height) => start + lastChild!.getMinIntrinsicWidth(height);
  @override
  double computeMaxIntrinsicHeight(double width) => math.max(frostStatusDotExtent, lastChild!.getMaxIntrinsicHeight(math.max(0, width - start)));
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : computeMaxIntrinsicWidth(double.infinity);
    final text = lastChild!.getDryLayout(BoxConstraints(maxWidth: math.max(0, width - start)));
    return constraints.constrain(Size(width, math.max(frostStatusDotExtent, text.height)));
  }

  @override
  void performLayout() {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : computeMaxIntrinsicWidth(double.infinity);
    final dot = firstChild!, label = lastChild!;
    dot.layout(const BoxConstraints.tightFor(width: frostStatusDotExtent, height: frostStatusDotExtent), parentUsesSize: true);
    label.layout(BoxConstraints(maxWidth: math.max(0, width - start)), parentUsesSize: true);
    final painter = TextPainter(
      text: TextSpan(text: spec.text, style: spec.style),
      textDirection: spec.direction,
      textScaler: spec.scaler,
    )..layout(maxWidth: label.size.width);
    final firstLine = painter
        .getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: spec.text.length), boxHeightStyle: BoxHeightStyle.includeLineSpacingMiddle)
        .firstOrNull;
    final center = firstLine?.toRect().center.dy ?? painter.preferredLineHeight / 2;
    painter.dispose();
    final top = math.max(0.0, center - frostStatusDotExtent / 2);
    size = constraints.constrain(Size(width, math.max(label.size.height, top + frostStatusDotExtent)));
    (dot.parentData! as _StatusSubtitleData).offset = Offset(spec.direction == TextDirection.ltr ? 0 : width - frostStatusDotExtent, top);
    (label.parentData! as _StatusSubtitleData).offset = Offset(spec.direction == TextDirection.ltr ? start : 0, 0);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
