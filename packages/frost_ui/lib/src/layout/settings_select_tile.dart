import 'package:flutter/widgets.dart';

import '../controls/picker_option.dart';
import '../display/status_dot.dart';
import '../feedback/_skeleton_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../lists/_row_scope.dart';
import '../lists/list_row.dart';
import '../overlays/_menu_target.dart';
import '../overlays/_value_picker.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';

/// A whole-row choice using the same wrapping and motion as every list row.
class FrostSettingsSelectTile<T extends Object> extends StatefulWidget {
  const FrostSettingsSelectTile({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.subtitleStatus,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
  });
  FrostSettingsSelectTile.values({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.subtitleStatus,
    required this.value,
    required List<T> values,
    required String Function(T) label,
    required this.onChanged,
    this.enabled = true,
  }) : items = [for (final item in values) FrostPickerOption(value: item, label: label(item))];

  /// Optional leading icon. Omit it for text-only grouped settings; the title
  /// and its divider then share the group's content inset.
  final FrostIconData? icon;
  final String title;
  final String? subtitle;
  final FrostStatusTone? subtitleStatus;
  final T value;
  final List<FrostPickerOption<T>> items;
  final ValueChanged<T> onChanged;
  final bool enabled;
  @override
  State<FrostSettingsSelectTile<T>> createState() => _SettingsSelectTileState<T>();
}

class _SettingsSelectTileState<T extends Object> extends State<FrostSettingsSelectTile<T>> {
  final _valueKey = GlobalKey();
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final label = widget.items.where((item) => item.value == widget.value).firstOrNull?.label ?? '';
    final enabled = widget.enabled && widget.items.isNotEmpty && FrostControlScope.enabledOf(context);
    Widget content = FrostMenuTarget(
      targetKey: _valueKey,
      child: FrostPickerMenuHost<T>(
        items: widget.items,
        value: widget.value,
        title: widget.title,
        onSelected: widget.onChanged,
        enabled: enabled,
        builder: (context, focusNode, toggle) => Semantics(
          button: true,
          label: widget.title,
          value: [label, ?widget.subtitle].join(' · '),
          enabled: enabled,
          onTap: enabled ? toggle : null,
          excludeSemantics: true,
          child: FrostRowFocus(
            focusNode: focusNode,
            child: FrostListRow(
              title: widget.title,
              subtitle: widget.subtitle,
              subtitleStatus: widget.subtitleStatus,
              icon: widget.icon,
              enabled: enabled,
              onPressed: toggle,
              trailing: KeyedSubtree(
                key: ValueKey(label),
                child: SizedBox(
                  key: _valueKey,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FrostSkeletonText(
                          child: Text(label, style: FrostTypography.of(context).style(FrostTextRole.body).copyWith(color: tokens.textSecondary)),
                        ),
                      ),
                      const SizedBox(width: FrostGap.inline),
                      FrostIcon(
                        FrostControlScope.toolbarOf(context)
                            ? FrostScope.configOf(context).icons.chevronDown
                            : FrostScope.configOf(context).icons.chevronUpDown,
                        size: FrostControlSize.regular.iconSize,
                        color: tokens.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // Standalone settings rows retain their established inset. Inside a content
    // column or grouped section they obey that placement's common row rules.
    if (FrostKeyline.maybeOf(context) == null) {
      content = FrostKeyline(
        leadingRoom: 0,
        trailingRoom: 0,
        edgeDistanceStart: 0,
        edgeDistanceEnd: 0,
        insideContainer: true,
        contentStart: FrostGap.of(context).rowInset,
        child: content,
      );
    }
    return content;
  }
}
