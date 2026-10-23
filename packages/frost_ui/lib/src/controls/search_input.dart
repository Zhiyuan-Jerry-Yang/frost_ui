import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../display/data_dot.dart';
import '../feedback/activity_indicator.dart';
import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../layout/content_viewport.dart';
import '../lists/_list_input.dart';
import '../lists/list.dart';
import '../lists/list_row.dart';
import '../overlays/_anchored_panel_layout.dart';
import '../overlays/_popover_surface.dart';
import '../overlays/adaptive_panel.dart';
import '../primitives/presence.dart';
import '../primitives/text.dart';
import '_field_clear_button.dart';
import '_field_options.dart';
import 'buttons.dart';
import 'picker.dart';
import 'picker_option.dart';
import 'search_suggestion.dart';
import 'text_field.dart';
import 'token_field.dart';

typedef _Suggestion = ({FrostSearchSuggestion item, String? title});

/// Search input using the caller's controller directly, including token rules.
/// Suggestions stay anchored by default and never take editing focus. Supply
/// layoutBuilder to compose the same input and suggestion list into page slots.
class FrostSearchInput<S> extends StatefulWidget {
  const FrostSearchInput({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onSubmitted,
    this.onClear,
    this.actions = const [],
    this.leadingIcon = false,
    this.autofocus = false,
    this.size,
    this.scopes,
    this.scope,
    this.onScopeChanged,
    this.suggestions = const [],
    this.loading = false,
    this.message,
    this.layoutBuilder,
    super.key,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final String placeholder;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onClear;

  /// Structural actions should be compact FrostButton.icon controls.
  final List<Widget> actions;

  /// Optional decorative search icon. The trailing submit action is always
  /// available, so queries can be submitted without opening a soft keyboard.
  final bool leadingIcon;
  final FrostControlSize? size;
  final List<FrostPickerOption<S>>? scopes;
  final S? scope;
  final ValueChanged<S>? onScopeChanged;
  final List<FrostSearchSuggestionGroup> suggestions;

  /// Shows progress in the anchored suggestion viewport, retaining existing
  /// items. Progress is not selectable and does not intercept editing keys.
  final bool loading;

  /// Application-provided loading, empty-result, or failure explanation.
  /// Shown in the same scrollable panel even when suggestions are empty.
  final String? message;

  /// Composes the stable field (including optional scopes) and a non-focusing
  /// suggestion list in narrow available space. On wide viewports suggestions
  /// remain anchored to the actual field and this builder receives null.
  /// Suggestions are null when hidden or empty, including loading-only states.
  /// Give a visible list finite height and avoid the keyboard with viewInsets;
  /// keep the supplied field mounted exactly once when changing page slots.
  final Widget Function(BuildContext context, Widget field, Widget? suggestions)? layoutBuilder;
  @override
  State<FrostSearchInput<S>> createState() => _SearchInputState<S>();
}

class _SearchInputState<S> extends State<FrostSearchInput<S>> {
  final _overlay = OverlayPortalController();
  final _fieldKey = GlobalKey();
  final _listKey = GlobalKey();
  final _list = FrostListInputController<_Suggestion>();
  final _highlightRevision = ValueNotifier<int>(0);
  List<_Suggestion> _entries = const [], _lastEntries = const [];
  _Suggestion? _highlighted;
  String _text = '';
  bool _suppressed = false;
  int _generation = 0;
  bool _embedded = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _embedded = widget.layoutBuilder != null && frostPanelUsesSheet(context);
  }

  bool get _visible => widget.focusNode.hasFocus && !_suppressed && (_entries.isNotEmpty || !_embedded && (widget.loading || widget.message != null));
  @override
  void initState() {
    super.initState();
    _text = widget.controller.text;
    _readEntries();
    widget.controller.addListener(_queryChanged);
    widget.focusNode.addListener(_focusChanged);
    // Always attach a portal. Visibility is derived during layout so supplied
    // suggestions get correct geometry on the very first frame.
    _overlay.show();
  }

  void _readEntries() {
    _entries = [
      for (final group in widget.suggestions)
        for (var i = 0; i < group.items.length; i++) (item: group.items[i], title: i == 0 ? group.title : null),
    ];
    if (!listEquals(_entries, _lastEntries) && _list.attached) {
      // A remove button can temporarily hover another row; list mutations
      // restore the keyboard item, including the input's announcement.
      _highlighted = _list.keyboardItem;
    }
    if (_highlighted != null) {
      final next = _entries.where((entry) => identical(entry.item, _highlighted!.item)).firstOrNull;
      if (next != null) {
        _highlighted = next;
      } else {
        final index = _lastEntries.indexOf(_highlighted!);
        _highlighted = _entries.isEmpty ? null : _entries[index.clamp(0, _entries.length - 1)];
      }
    }
    if (_entries.isNotEmpty) _lastEntries = _entries;
  }

  @override
  void didUpdateWidget(FrostSearchInput<S> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _embedded = widget.layoutBuilder != null && frostPanelUsesSheet(context);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_queryChanged);
      widget.controller.addListener(_queryChanged);
      _text = widget.controller.text;
      _suppressed = false;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_focusChanged);
      widget.focusNode.addListener(_focusChanged);
    }
    _readEntries();
  }

  void _queryChanged() {
    if (_text == widget.controller.text) return;
    _text = widget.controller.text;
    setState(() {
      _suppressed = false;
      _highlighted = null;
      _generation++;
    });
  }

  void _focusChanged() {
    setState(() {
      _suppressed = false;
      _highlighted = null;
      _generation++;
    });
  }

  void _dismiss() {
    if (!mounted) return;
    setState(() {
      _suppressed = true;
      _highlighted = null;
    });
  }

  void _select(_Suggestion entry) {
    try {
      entry.item.onSelected();
    } finally {
      // Updating the query as part of choosing an item is still this selection.
      // Reopen only for a later query edit or a new focus entry.
      if (mounted) _dismiss();
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent || !widget.focusNode.hasFocus) return KeyEventResult.ignored;
    final composing = widget.controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape && _visible) {
      _dismiss();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && !_visible && _entries.isNotEmpty) {
      setState(() {
        _suppressed = false;
        _highlighted = null;
        _generation++;
      });
      return KeyEventResult.handled;
    }
    if (_visible &&
        (event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.enter)) {
      final result = _list.handle?.call(event) ?? KeyEventResult.ignored;
      if (result == KeyEventResult.handled) return result;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _submit(widget.controller.text);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit(String value) {
    if (_visible && _highlighted != null) {
      _select(_highlighted!);
    } else {
      widget.onSubmitted(value);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_queryChanged);
    widget.focusNode.removeListener(_focusChanged);
    _highlightRevision.dispose();
    super.dispose();
  }

  Widget _field() => ListenableBuilder(
    listenable: Listenable.merge([widget.controller, _highlightRevision]),
    builder: (context, _) {
      final leading = widget.leadingIcon ? FrostIconSet.of(context).search : null;
      final trailing = FrostControlScope(
        size: FrostControlSize.compact,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostFieldClearButton(visible: widget.controller.text.isNotEmpty, onClear: widget.onClear ?? widget.controller.clear),
            ...widget.actions,
            FrostButton.icon(
              icon: FrostIconSet.of(context).forward,
              label: FrostScope.labelsOf(context).search,
              size: FrostControlSize.compact,
              onPressed: widget.controller.text.trim().isEmpty ? null : () => widget.onSubmitted(widget.controller.text),
            ),
          ],
        ),
      );
      final index = _highlighted == null ? -1 : _entries.indexOf(_highlighted!);
      final announcement = index < 0
          ? null
          : '${_highlighted!.item.label}${_highlighted!.item.inlineDetail && _highlighted!.item.detail != null ? ', ${_highlighted!.item.detail}' : ''} ${FrostScope.labelsOf(context).itemPosition(index + 1, _entries.length)}';
      final Widget field;
      if (widget.controller case final FrostTokenEditingController tokens) {
        field = FrostTokenField(
          controller: tokens,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          placeholder: widget.placeholder,
          onSubmitted: _submit,
          onEditingComplete: () {},
          onTapOutside: (_) => widget.focusNode.unfocus(),
          textInputAction: TextInputAction.search,
          leading: leading,
          trailing: trailing,
          size: widget.size,
        );
      } else {
        field = FrostTextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          placeholder: widget.placeholder,
          onSubmitted: _submit,
          onEditingComplete: () {},
          onTapOutside: (_) => widget.focusNode.unfocus(),
          textInputAction: TextInputAction.search,
          leading: leading,
          trailing: trailing,
          size: widget.size,
        );
      }
      return FrostFieldOptions(semanticHint: announcement, child: field);
    },
  );
  Widget _suggestionList(BuildContext context) => KeyedSubtree(
    key: _listKey,
    child: FrostListInput<_Suggestion>(
      controller: _list,
      footer: widget.loading || widget.message != null
          ? _suggestionColumn(
              Padding(
                padding: EdgeInsets.only(top: _entries.isEmpty ? 0 : FrostGap.related),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.loading) FrostActivityIndicator(size: FrostControlSize.compact, semanticLabel: FrostScope.labelsOf(context).loading),
                    if (widget.loading && widget.message != null) const SizedBox(width: FrostGap.related),
                    if (widget.message case final message?)
                      Expanded(
                        child: FrostText(message, role: FrostTextRole.footnote, tone: FrostTextTone.secondary),
                      ),
                  ],
                ),
              ),
            )
          : null,
      identity: (entry) => entry.item,
      onHighlight: (item, _) {
        _highlighted = item;
        _highlightRevision.value++;
      },
      child: FrostList<_Suggestion>(
        key: ValueKey(_generation),
        items: _visible ? _entries : _lastEntries,
        reserveIconColumn: (_visible ? _entries : _lastEntries).any((entry) => entry.item.icon != null || entry.item.dataColor != null),
        onSelected: _select,
        itemBuilder: (context, entry, _) => _suggestionColumn(
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (entry.title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: FrostGap.inline),
                  child: FrostText(entry.title!, role: FrostTextRole.caption, tone: FrostTextTone.tertiary),
                ),
              FrostListRow(
                title: entry.item.label,
                subtitle: entry.item.detail,
                inlineSubtitle: entry.item.inlineDetail,
                icon: entry.item.dataColor == null ? entry.item.icon : null,
                leading: entry.item.dataColor == null ? null : FrostDataDot(entry.item.dataColor!),
                value: entry.item.value,
                trailing: entry.item.onRemove == null
                    ? null
                    : FrostButton.icon(
                        icon: FrostIconSet.of(context).close,
                        label: FrostScope.labelsOf(context).remove,
                        size: FrostControlSize.compact,
                        onPressed: entry.item.onRemove,
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _suggestionColumn(Widget child) => !_embedded ? child : FrostContentColumn(child: child);

  Widget _fieldRegion() => KeyedSubtree(
    key: _fieldKey,
    child: TextFieldTapRegion(
      child: TapRegion(
        groupId: this,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _field(),
            if (widget.scopes?.isNotEmpty ?? false)
              FrostPresence(
                visible: widget.focusNode.hasFocus || widget.controller.text.isNotEmpty,
                effect: FrostPresenceEffect.expand,
                alignment: AlignmentDirectional.topStart,
                child: Padding(
                  padding: const EdgeInsets.only(top: FrostGap.related),
                  child: FrostPicker<S>.segmented(options: widget.scopes!, value: widget.scope, onChanged: widget.onScopeChanged, label: widget.placeholder),
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _panel(BuildContext context, OverlayChildLayoutInfo info) {
    final field = _fieldKey.currentContext?.findRenderObject();
    if (field is! RenderBox || !field.hasSize) return const SizedBox.shrink();
    // OverlayPortal uses its nearest Navigator overlay. A root-overlay origin
    // would count an offset content pane twice in a nested shell.
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final anchor = overlay.globalToLocal(field.localToGlobal(Offset.zero)) & field.size;
    final media = MediaQuery.of(this.context);
    final insets = EdgeInsets.fromLTRB(media.padding.left, media.padding.top, media.padding.right, math.max(media.padding.bottom, media.viewInsets.bottom));
    final maximumHeight = math.max(0.0, (info.overlaySize.height - insets.vertical) / 2);
    return MediaQuery(
      data: media,
      child: CustomSingleChildLayout(
        delegate: FrostAnchoredPanelLayout(anchor: anchor, offset: frostAnchoredPanelGap, below: true, margin: frostAnchoredPanelMargin, insets: insets),
        child: TextFieldTapRegion(
          child: TapRegion(
            groupId: this,
            onTapOutside: (_) => _dismiss(),
            child: FrostPresence(
              visible: _visible,
              alignment: AlignmentDirectional.topStart,
              child: ExcludeFocus(
                child: SizedBox(
                  width: anchor.width,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maximumHeight),
                    child: FrostControlScope(
                      toolbar: false,
                      size: FrostControlSize.regular,
                      enabled: true,
                      child: FrostPopoverSurface(child: _suggestionList(context)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final field = _fieldRegion();
    final Widget content;
    if (widget.layoutBuilder case final builder?) {
      final suggestions = !_embedded || !_visible
          ? null
          : ExcludeFocus(
              child: TextFieldTapRegion(
                child: TapRegion(
                  groupId: this,
                  onTapOutside: (_) => _dismiss(),
                  child: FrostControlScope(toolbar: false, size: FrostControlSize.regular, enabled: true, child: _suggestionList(context)),
                ),
              ),
            );
      content = builder(context, field, suggestions);
    } else {
      content = field;
    }
    return Focus(
      onKeyEvent: _key,
      canRequestFocus: false,
      skipTraversal: true,
      // Keep the portal attached across presentation changes. Its controller's
      // showing state otherwise resets when a page switches back to anchoring.
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _overlay,
        overlayChildBuilder: (context, info) => !_embedded ? _panel(context, info) : const SizedBox.shrink(),
        child: content,
      ),
    );
  }
}

/// Centres the search row in its page column with equal vertical breathing room.
class FrostSearchInputRegion extends StatelessWidget {
  const FrostSearchInputRegion({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => FrostContentColumn(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: FrostGap.related),
      child: child,
    ),
  );
}
