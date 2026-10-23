import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controls/shortcuts.dart' show FrostShortcut, frostShortcutLabel;
import '../foundation/_menu_metrics.dart';
import '../foundation/metrics.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/divider.dart';
import '../primitives/icon.dart';
import '../primitives/text.dart';
import '_menu_item.dart';
import '_menu_panel.dart';
import 'menu_anchor.dart';
import 'tooltip.dart';

/// Shared menu content, independent of the control that opens it.
sealed class FrostMenuEntry {
  const FrostMenuEntry();
}

class FrostMenuAction extends FrostMenuEntry {
  const FrostMenuAction(this.label, {this.icon, this.onSelected, this.checked, this.enabled = true, this.destructive = false, this.shortcut, this.tooltip});
  final String label;
  final FrostIconData? icon;
  final VoidCallback? onSelected;
  final bool? checked;
  final bool destructive;
  final bool enabled;

  /// Additional help, including why a disabled action is unavailable.
  /// Displayed by FrostTooltip and announced once as a semantics hint.
  final String? tooltip;

  /// Display only; register the binding in FrostShortcuts to handle the key.
  final FrostShortcut? shortcut;
}

class FrostMenuSection extends FrostMenuEntry {
  const FrostMenuSection({this.header, required this.entries});
  final String? header;
  final List<FrostMenuEntry> entries;
}

class FrostMenuSubmenu extends FrostMenuEntry {
  const FrostMenuSubmenu(this.label, {this.icon, required this.entries});
  final String label;
  final FrostIconData? icon;
  final List<FrostMenuEntry> entries;
}

class FrostMenuDivider extends FrostMenuEntry {
  const FrostMenuDivider();
}

/// One content renderer for controls, nested menus and context menus.
List<Widget> frostMenuChildren(BuildContext context, List<FrostMenuEntry> entries) {
  bool hasLeading(FrostMenuEntry entry) => switch (entry) {
    FrostMenuAction(:final icon, :final checked) => icon != null || checked != null,
    FrostMenuSubmenu(:final icon) => icon != null,
    FrostMenuSection(:final entries) => entries.any(hasLeading),
    _ => false,
  };
  final columns = _MenuColumns(entries.any(hasLeading));
  final result = <Widget>[];
  final group = <FrostMenuEntry>[];
  void flush() {
    if (group.isEmpty) return;
    result.addAll(_renderGroup(context, group, columns: columns));
    group.clear();
  }

  for (final entry in entries) {
    switch (entry) {
      case FrostMenuSection(:final header, :final entries):
        flush();
        result.addAll(_renderGroup(context, entries, header: header, columns: columns));
      case FrostMenuDivider():
        flush();
        result.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: FrostMenuMetrics.rowInset),
            child: FrostDivider(),
          ),
        );
      default:
        group.add(entry);
    }
  }
  flush();
  return result;
}

class _MenuColumns {
  const _MenuColumns(this.reserved);
  final bool reserved;
  // A single panel-wide slot displays either a check or an icon. A submenu
  // computes its own slot from its own entries, without inheriting parent gaps.
  double get leading => reserved ? FrostControlSize.compact.iconSize + FrostMenuMetrics.iconGap : 0;
}

List<Widget> _renderGroup(BuildContext context, List<FrostMenuEntry> entries, {String? header, required _MenuColumns columns}) {
  final tokens = FrostThemeTokens.of(context);
  bool focusable(FrostMenuEntry e) => switch (e) {
    FrostMenuAction(:final enabled, :final onSelected) => enabled && onSelected != null,
    FrostMenuSubmenu(:final entries) => entries.isNotEmpty,
    _ => false,
  };
  final preferred = entries.where((e) => e is FrostMenuAction && e.checked == true && focusable(e)).firstOrNull ?? entries.where(focusable).firstOrNull;
  return [
    if (header != null)
      Padding(
        padding: EdgeInsetsDirectional.fromSTEB(FrostMenuMetrics.rowInset + columns.leading, FrostGap.related, FrostMenuMetrics.rowInset, FrostGap.related),
        child: DefaultTextStyle(
          style: TextStyle(color: tokens.textTertiary),
          child: FrostText(header, role: FrostTextRole.caption),
        ),
      ),
    for (final entry in entries)
      ...switch (entry) {
        FrostMenuAction(:final label, :final icon, :final onSelected, :final enabled, :final checked, :final destructive, :final shortcut, :final tooltip) => [
          _ActionTooltip(
            message: tooltip,
            child: MergeSemantics(
              child: Semantics(
                checked: checked,
                hint: [if (tooltip?.isNotEmpty == true) tooltip!, if (shortcut != null) frostShortcutLabel(context, shortcut)].join(' · '),
                child: FrostMenuItem(
                  onPressed: enabled ? onSelected : null,
                  autofocus: identical(entry, preferred),
                  child: _MenuEntryRow(
                    label: label,
                    icon: icon,
                    checked: checked,
                    destructive: destructive,
                    shortcut: shortcut == null ? null : frostShortcutLabel(context, shortcut),
                    columns: columns,
                  ),
                ),
              ),
            ),
          ),
        ],
        FrostMenuSubmenu(:final label, :final icon, :final entries) => [
          _MenuSubmenu(label: label, icon: icon, entries: entries, columns: columns, autofocus: identical(entry, preferred)),
        ],
        FrostMenuSection(:final header, :final entries) => _renderGroup(context, entries, header: header, columns: columns),
        FrostMenuDivider() => [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: FrostMenuMetrics.rowInset),
            child: FrostDivider(),
          ),
        ],
      },
  ];
}

/// Keep unchanged menu entries free of an extra gesture/semantics wrapper.
class _ActionTooltip extends StatelessWidget {
  const _ActionTooltip({required this.message, required this.child});
  final String? message;
  final Widget child;
  @override
  Widget build(BuildContext context) => message == null || message!.isEmpty ? child : FrostTooltip(message: message!, excludeFromSemantics: true, child: child);
}

class _MenuEntryRow extends StatelessWidget {
  const _MenuEntryRow({required this.label, required this.columns, this.icon, this.checked, this.destructive = false, this.shortcut, this.arrow});
  final String label;
  final _MenuColumns columns;
  final FrostIconData? icon, arrow;
  final bool? checked;
  final bool destructive;
  final String? shortcut;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context), icons = FrostIconSet.of(context);
    final dimension = FrostControlSize.compact.iconSize;
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: destructive ? tokens.negativeInk : tokens.textPrimary),
      duration: FrostMotion.duration(context, FrostMotion.hover),
      curve: FrostMotion.hoverCurve,
      builder: (context, ink, _) => Row(
        children: [
          if (columns.reserved)
            SizedBox(
              width: columns.leading,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: checked == true
                    ? FrostIcon(icons.check, size: dimension, color: tokens.selectionInk)
                    : icon == null
                    ? null
                    : TweenAnimationBuilder<Color?>(
                        tween: ColorTween(end: destructive ? tokens.negativeInk : tokens.textSecondary),
                        duration: FrostMotion.duration(context, FrostMotion.hover),
                        builder: (context, color, _) => FrostIcon(icon!, size: dimension, color: color),
                      ),
              ),
            ),
          Expanded(
            child: DefaultTextStyle(
              style: TextStyle(color: ink),
              child: FrostText(label, role: FrostTextRole.callout),
            ),
          ),
          if (shortcut != null || arrow != null) const SizedBox(width: FrostMenuMetrics.iconGap),
          if (shortcut case final shortcut?)
            DefaultTextStyle(
              style: TextStyle(color: tokens.textTertiary),
              child: ExcludeSemantics(child: FrostText(shortcut, role: FrostTextRole.footnote)),
            ),
          if (arrow case final arrow?) FrostIcon(arrow, size: dimension, color: tokens.textTertiary),
        ],
      ),
    );
  }
}

class _MenuSubmenu extends StatefulWidget {
  const _MenuSubmenu({required this.label, required this.icon, required this.entries, required this.columns, required this.autofocus});
  final String label;
  final FrostIconData? icon;
  final List<FrostMenuEntry> entries;
  final _MenuColumns columns;
  final bool autofocus;
  @override
  State<_MenuSubmenu> createState() => _MenuSubmenuState();
}

class _MenuSubmenuState extends State<_MenuSubmenu> with SingleTickerProviderStateMixin {
  final _controller = MenuController();
  final _focus = FocusNode(debugLabel: 'Submenu trigger');
  final _menuFocus = FocusScopeNode(debugLabel: 'Submenu');
  late final _reveal = AnimationController.unbounded(vsync: this);
  bool _closing = false;
  void _open({bool focusMenu = false}) {
    if (!_controller.isOpen) _controller.open();
    if (focusMenu) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.isOpen && !_closing) {
          _menuFocus.requestFocus();
          _menuFocus.nextFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _menuFocus.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final icons = FrostIconSet.of(context);
    return RawMenuAnchor(
      useRootOverlay: true,
      controller: _controller,
      childFocusNode: _focus,
      onOpenRequested: (position, showOverlay) {
        showOverlay();
        _closing = false;
        FrostMotion.springTo(context, _reveal, 1, FrostMotion.standard);
      },
      onCloseRequested: (hideOverlay) {
        if (!_controller.isOpen) {
          hideOverlay();
          return;
        }
        _closing = true;
        FrostMotion.springTo(context, _reveal, 0, FrostMotion.snappy).orCancel.then((_) {
          if (mounted && _closing) hideOverlay();
        }, onError: (_) {});
      },
      overlayBuilder: (context, info) => CustomSingleChildLayout(
        delegate: _SubmenuLayout(anchor: info.anchorRect, rtl: rtl),
        child: TapRegion(
          groupId: info.tapRegionGroupId,
          child: FocusScope(
            node: _menuFocus,
            child: Shortcuts(
              shortcuts: {
                SingleActivator(rtl ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft): const DismissIntent(),
                const SingleActivator(LogicalKeyboardKey.escape): const DismissIntent(),
              },
              child: Actions(
                actions: {
                  DismissIntent: CallbackAction<DismissIntent>(
                    onInvoke: (_) {
                      _controller.close();
                      _focus.requestFocus();
                      return null;
                    },
                  ),
                },
                child: FrostMenuReveal(
                  reveal: _reveal,
                  closing: () => _closing,
                  alignment: AlignmentDirectional.topStart,
                  child: FrostMenuPanel(children: frostMenuChildren(context, widget.entries)),
                ),
              ),
            ),
          ),
        ),
      ),
      builder: (context, controller, _) => Shortcuts(
        shortcuts: {SingleActivator(rtl ? LogicalKeyboardKey.arrowLeft : LogicalKeyboardKey.arrowRight): const ActivateIntent()},
        child: Actions(
          actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => _open(focusMenu: true))},
          child: FrostMenuItem(
            focusNode: _focus,
            autofocus: widget.autofocus,
            closeOnActivate: false,
            // Opening is idempotent: a click after desktop hover must not toggle
            // the submenu shut. SubmenuButton assumes a Material menu parent;
            // the outer FrostMenuAnchor intentionally uses RawMenuAnchor.
            onPressed: widget.entries.isEmpty ? null : () => _open(focusMenu: true),
            onHover: (hover) {
              if (hover && widget.entries.isNotEmpty) _open();
            },
            child: _MenuEntryRow(label: widget.label, icon: widget.icon, columns: widget.columns, arrow: rtl ? icons.chevronLeft : icons.chevronRight),
          ),
        ),
      ),
    );
  }
}

class _SubmenuLayout extends SingleChildLayoutDelegate {
  const _SubmenuLayout({required this.anchor, required this.rtl});
  final Rect anchor;
  final bool rtl;
  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(maxWidth: math.max(0, constraints.maxWidth - FrostGap.related * 2), maxHeight: math.max(0, constraints.maxHeight - FrostGap.related * 2));
  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final right = anchor.right;
    final left = anchor.left - childSize.width;
    final fitsRight = right + childSize.width <= size.width - FrostGap.related;
    final fitsLeft = left >= FrostGap.related;
    final x = rtl ? (fitsLeft ? left : right) : (fitsRight ? right : left);
    return Offset(
      x.clamp(FrostGap.related, math.max(FrostGap.related, size.width - childSize.width - FrostGap.related)).toDouble(),
      anchor.top.clamp(FrostGap.related, math.max(FrostGap.related, size.height - childSize.height - FrostGap.related)).toDouble(),
    );
  }

  @override
  bool shouldRelayout(_SubmenuLayout oldDelegate) => anchor != oldDelegate.anchor || rtl != oldDelegate.rtl;
}
