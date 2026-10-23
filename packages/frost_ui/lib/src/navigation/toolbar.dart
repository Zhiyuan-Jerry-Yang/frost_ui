import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../controls/_toolbar_geometry.dart';
import '../controls/picker.dart';
import '../controls/picker_option.dart';
import '../display/label.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/icon_data.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../layout/auto_scaffold.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '../primitives/keyline.dart';
import '../primitives/text.dart';
import 'sort_menu.dart';
import 'toolbar_menu_button.dart';

part 'toolbar_item.dart';
part 'toolbar_layout.dart';

/// One row whose variants are measured and selected during the same layout.
class FrostToolbar extends StatefulWidget {
  const FrostToolbar({
    this.leading = const [],
    this.controls = const [],
    this.middle,
    this.collapsedMiddle,
    this.middleMaxWidth = 360,
    this.trailing = const [],
    super.key,
  }) : assert(middleMaxWidth > 0 && middleMaxWidth < double.infinity);

  /// Text, labels and menus retain natural width. Other leading widgets occupy
  /// one compact icon target, like an AppBar leading slot; their internals are
  /// never inspected to discover painted bounds.
  final List<Widget> leading;

  /// Natural-width controls immediately after leading content. They share one
  /// priority/overflow pass with trailing actions and the same More menu.
  /// Use middle only for flexible, non-menu content such as a search field.
  final List<FrostToolbarItem> controls;
  final Widget? middle, collapsedMiddle;

  /// The middle slot grows continuously up to this finite positive width,
  /// immediately after leading controls. It never reduces trailing item widths
  /// or changes the existing compact/overflow order. The default remains 360.
  final double middleMaxWidth;
  final List<FrostToolbarItem> trailing;

  @override
  State<FrostToolbar> createState() => _FrostToolbarState();
}

class _FrostToolbarState extends State<FrostToolbar> {
  final FrostLayoutIdentity _identity = FrostLayoutIdentity();
  List<Widget> get leading => widget.leading;
  List<FrostToolbarItem> get trailing => [...widget.controls, ...widget.trailing];
  Widget? get middle => widget.middle;
  Widget? get collapsedMiddle => widget.collapsedMiddle;
  bool _iconSlot(Widget widget) =>
      !(widget is Text ||
          widget is FrostText ||
          widget is FrostLabel ||
          widget is FrostToolbarTitle ||
          widget is FrostTitleMenu ||
          widget is FrostToolbarMenuButton && widget.showsLabel);
  Widget _leadingChild(Widget widget, int index, double inset, double labelInset) {
    Widget child = widget;
    if (_iconSlot(widget)) {
      final hit = FrostDensity.of(context).targetHeight;
      final keyline = FrostKeyline.maybeOf(context);
      final shift = keyline == null || keyline.insideContainer || FrostOnMediaChromeScope.inkOf(context) != null
          ? 0.0
          : inset - (hit - FrostControlSize.compact.iconSize) / 2;
      // Fixed target geometry aligns the icon by construction. The slot includes
      // its edge offset, so the following leading/middle gap remains unchanged.
      child = SizedBox(
        width: hit + shift,
        height: hit,
        child: OverflowBox(alignment: AlignmentDirectional.centerEnd, minWidth: hit, maxWidth: hit, minHeight: hit, maxHeight: hit, child: widget),
      );
    }
    if (widget is FrostToolbarMenuButton && widget.showsLabel) child = FrostToolbarLeadingScope(child: child);
    if (widget is FrostLabel && widget.style == null && widget.icon != null) {
      child = LayoutBuilder(
        builder: (_, constraints) => FrostLabelPresentation(compact: constraints is _ToolbarConstraints && constraints.form == _Form.compact, child: widget),
      );
    }
    if (index != 0) return child;
    // Labels have no button hit inset of their own. Restore only the toolbar's
    // actual leading bleed; without a keyline there is no offset to compensate.
    var padding = 0.0;
    if (widget is FrostLabel) {
      padding = labelInset;
    } else if (widget is Text || widget is FrostText || widget is FrostToolbarTitle && widget.child is! FrostTitleMenu) {
      padding = inset;
    }
    return padding == 0
        ? child
        : Padding(
            padding: EdgeInsetsDirectional.only(start: padding),
            child: child,
          );
  }

  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hit = FrostDensity.of(context).targetHeight;
    final inset = FrostGap.of(context).hitInset;
    final iconWidth = math.max(hit, FrostControlSize.compact.iconSize + inset * 2);
    return FrostControlScope(
      size: FrostControlSize.compact,
      toolbar: true,
      child: Material(
        type: MaterialType.transparency,
        child: FrostBleed(
          amount: math.max(inset, (hit - FrostControlSize.compact.iconSize) / 2),
          child: Builder(
            builder: (context) {
              final keyline = FrostKeyline.maybeOf(context);
              final outsets = frostBleedOutsetsOf(context).resolve(Directionality.of(context));
              final labelInset = math.min(inset, Directionality.of(context) == TextDirection.ltr ? outsets.left : outsets.right);
              final direction = Directionality.of(context);
              final extraStart = math.max(0.0, (direction == TextDirection.ltr ? outsets.left : outsets.right) - inset);
              final extraEnd = math.max(0.0, (direction == TextDirection.ltr ? outsets.right : outsets.left) - inset);
              return LayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: extraStart, end: extraEnd),
                    child: FrostLayoutCrossfade(
                      layoutIdentity: _identity,
                      child: _ToolbarLayout(
                        identity: _identity,
                        width: math.max(0, viewport.maxWidth - extraStart - extraEnd),
                        minimumMiddle: math.min(widget.middleMaxWidth, FrostAutoScaffold.usesHorizontalLayoutOf(context) ? 200 : 160),
                        maximumMiddle: widget.middleMaxWidth,
                        collapsedWidth: collapsedMiddle == null ? 0 : iconWidth,
                        hasMiddle: middle != null,
                        gap: FrostGap.related,
                        edgeInset: keyline == null || keyline.insideContainer || FrostOnMediaChromeScope.inkOf(context) != null ? null : inset,
                        startRoom: extraStart,
                        endRoom: extraEnd,
                        minimumHeight: hit,
                        direction: Directionality.of(context),
                        items: trailing,
                        controlsCount: widget.controls.length,
                        iconInset: (hit - FrostControlSize.compact.iconSize) / 2,
                        children: [
                          for (final (index, widget) in leading.indexed) ...[
                            _ToolbarSlot(
                              kind: _Kind.leading,
                              index: index,
                              title:
                                  widget is FrostToolbarTitle && widget.child is! FrostTitleMenu ||
                                  widget is Text ||
                                  widget is FrostText ||
                                  widget is FrostToolbarMenuButton && widget.showsLabel ||
                                  widget is FrostLabel && widget.icon == null && widget.style == null,
                              shrinkPriority: widget is FrostToolbarMenuButton ? 0 : 1,
                              titleMinimum:
                                  widget is FrostTitleMenu ||
                                      widget is FrostToolbarMenuButton && widget.showsLabel ||
                                      widget is FrostToolbarTitle && widget.child is FrostTitleMenu
                                  ? inset * 2 + FrostGap.inline + FrostControlSize.compact.iconSize
                                  : 0,
                              child: _leadingChild(widget, index, inset, labelInset),
                            ),
                            if (widget is FrostLabel && widget.style == null && widget.icon != null)
                              _ToolbarSlot(
                                kind: _Kind.leadingCompactMeasure,
                                index: index,
                                child: ExcludeFocus(
                                  child: ExcludeSemantics(
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.only(start: index == 0 ? labelInset : 0),
                                      child: FrostLabel(title: widget.title, icon: widget.icon, style: FrostLabelStyle.iconOnly),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                          for (final (index, item) in trailing.indexed) ...[
                            for (final compact in [false, if (item._canCompact) true])
                              _ToolbarSlot(
                                kind: compact ? _Kind.compactMeasure : _Kind.fullMeasure,
                                index: index,
                                child: ExcludeFocus(
                                  child: ExcludeSemantics(
                                    child: item is _Custom ? SizedBox(width: item.minWidth, height: hit) : item._build(context, compact),
                                  ),
                                ),
                              ),
                            _ToolbarSlot(
                              kind: _Kind.item,
                              index: index,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final data = constraints as _ToolbarConstraints;
                                  final form = data.form;
                                  return TickerMode(
                                    enabled: form != _Form.hidden,
                                    child: FrostToolbarEdge(
                                      trailing: data.trailingEdge,
                                      child: ExcludeFocus(
                                        excluding: form == _Form.hidden,
                                        child: Offstage(offstage: form == _Form.hidden, child: item._build(context, form == _Form.compact)),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (middle != null)
                            _ToolbarSlot(
                              kind: _Kind.middle,
                              child: LayoutBuilder(
                                builder: (context, constraints) => switch ((constraints as _ToolbarConstraints).middle) {
                                  _Middle.full => middle!,
                                  _Middle.collapsed => collapsedMiddle!,
                                  _Middle.hidden => const SizedBox.shrink(),
                                },
                              ),
                            ),
                          _ToolbarSlot(
                            kind: _Kind.moreMeasure,
                            child: ExcludeFocus(
                              child: ExcludeSemantics(
                                child: FrostToolbarControl(
                                  label: FrostScope.labelsOf(context).more,
                                  icon: FrostIconSet.of(context).more,
                                  showsLabel: false,
                                  onPressed: () {},
                                ),
                              ),
                            ),
                          ),
                          _ToolbarSlot(
                            kind: _Kind.more,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final overflow = (constraints as _ToolbarConstraints).overflow;
                                if (overflow.isEmpty) return const SizedBox.shrink();
                                return FrostToolbarEdge(
                                  trailing: true,
                                  child: FrostAdaptiveMenuAnchor(
                                    entries: [for (final index in overflow) trailing[index]._overflow(context)],
                                    builder: (context, focus, toggle) => FrostToolbarControl(
                                      label: FrostScope.labelsOf(context).more,
                                      icon: FrostIconSet.of(context).more,
                                      showsLabel: false,
                                      focusNode: focus,
                                      onPressed: toggle,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Internal title marker lets a page header constrain only its title.
class FrostToolbarTitle extends StatelessWidget {
  const FrostToolbarTitle({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(maxLines: 1, overflow: TextOverflow.ellipsis, child: child);
}
