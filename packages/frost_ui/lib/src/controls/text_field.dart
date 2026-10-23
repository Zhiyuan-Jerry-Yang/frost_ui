import 'package:flutter/material.dart';

import '../foundation/control_scope.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/icon.dart';
import '_field_clear_button.dart';
import '_field_frame.dart';
import '_field_layout.dart';
import '_field_options.dart';
import 'buttons.dart';
import 'form.dart';

// Field icon gaps are control geometry, independent of page spacing.
const _compactIconGap = 6.0, _regularIconGap = 8.0;

/// The shared input base. Labels and supporting text belong to Frost chrome.
class FrostTextField extends StatefulWidget {
  const FrostTextField({
    this.controller,
    this.focusNode,
    this.label,
    this.placeholder,
    this.help,
    this.error,
    this.leading,
    this.trailing,
    this.clearable = false,
    this.size,
    this.monospace = false,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.scrollController,
    super.key,
  }) : _secure = false,
       assert(minLines > 0 && maxLines >= minLines);

  /// A single-line password field with a visibility toggle. The keyboard type
  /// is always visiblePassword; autocorrection and suggestions are disabled.
  /// Obscuring, clearing, monospace and line-count options are not accepted.
  const FrostTextField.secure({
    this.controller,
    this.focusNode,
    this.label,
    this.placeholder,
    this.help,
    this.error,
    this.leading,
    this.trailing,
    this.size,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.scrollController,
    super.key,
  }) : _secure = true,
       obscureText = true,
       clearable = false,
       monospace = false,
       minLines = 1,
       maxLines = 1,
       keyboardType = TextInputType.visiblePassword;
  final bool _secure;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label, placeholder, help, error;
  final FrostIconData? leading;

  /// Structural accessory slot; use compact [FrostButton.icon] controls here.
  final Widget? trailing;
  final bool clearable, monospace, obscureText, readOnly, enabled, autofocus;
  final FrostControlSize? size;
  final int minLines, maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onEditingComplete, onTap;
  final TapRegionCallback? onTapOutside;
  final ScrollController? scrollController;
  @override
  State<FrostTextField> createState() => _FrostTextFieldState();
}

class _FrostTextFieldState extends State<FrostTextField> {
  late TextEditingController _controller = widget.controller ?? TextEditingController();
  late FocusNode _focus = widget.focusNode ?? FocusNode();
  // Input offsets belong to this live field, not its ancestor page's storage.
  late final _localScroll = ScrollController(keepScrollOffset: false);
  bool _passwordVisible = false;
  FrostFormCoordinator? _form;
  late final _formField = FrostFormFieldHandle(
    context: context,
    focusOf: () => _focus,
    errorOf: () => widget.error != null,
    enabledOf: () => widget.enabled && FrostControlScope.enabledOf(context),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final form = FrostFormScope.maybeOf(context);
    if (_form != form) {
      _form?.unregister(_formField);
      _form = form;
      _form?.register(_formField);
    }
    _formField.order = FrostFormOrder.of(context);
    _formField.beforeSubmit = FrostFieldOptions.of(context)?.beforeSubmit;
  }

  @override
  void didUpdateWidget(FrostTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._secure != widget._secure) _passwordVisible = false;
    if (oldWidget.controller != widget.controller) {
      final previous = _controller;
      _controller = widget.controller ?? TextEditingController.fromValue(previous.value);
      if (oldWidget.controller == null) previous.dispose();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) _focus.dispose();
      _focus = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    _form?.unregister(_formField);
    _localScroll.dispose();
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_controller, _focus]),
    builder: (context, _) {
      final tokens = FrostThemeTokens.of(context);
      final options = FrostFieldOptions.of(context);
      final enabled = widget.enabled && FrostControlScope.enabledOf(context);
      final invalid = widget.error != null || (options?.invalid ?? false);
      final size = widget.size ?? FrostControlScope.sizeOf(context);
      final geometry = frostControlGeometry(context, size);
      final style = FrostTypography.of(
        context,
      ).style(FrostTextRole.body, monospace: widget.monospace, numeric: options?.numeric ?? false).copyWith(color: tokens.textPrimary);
      final multiLine = widget.maxLines > 1;
      final gap = size == FrostControlSize.compact ? _compactIconGap : _regularIconGap;
      Widget editor(BuildContext context) {
        final automatic = _form != null && widget.textInputAction == null && !multiLine;
        final textEditor = TextField(
          controller: _controller,
          focusNode: _focus,
          readOnly: widget.readOnly,
          enabled: enabled,
          autofocus: widget.autofocus,
          obscureText: widget._secure ? !_passwordVisible : widget.obscureText,
          autocorrect: !widget._secure,
          enableSuggestions: !widget._secure,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction ?? (multiLine ? TextInputAction.newline : _form?.actionFor(_formField)),
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          onEditingComplete: automatic
              ? () {
                  widget.onEditingComplete?.call();
                  _form?.completeEditing(_formField);
                }
              : widget.onEditingComplete,
          onTap: widget.onTap,
          onTapOutside: widget.onTapOutside,
          scrollController: widget.scrollController ?? _localScroll,
          textAlignVertical: multiLine ? TextAlignVertical.top : TextAlignVertical.center,
          style: style,
          cursorColor: invalid ? tokens.negativeInk : tokens.fieldFocus,
          decoration: InputDecoration(
            isCollapsed: true,
            isDense: true,
            filled: false,
            contentPadding: EdgeInsets.zero,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            hintText: widget.placeholder,
            hintStyle: style.copyWith(color: tokens.textTertiary),
          ),
        );
        final hint = options?.semanticHint;
        return hint == null
            ? textEditor
            : MergeSemantics(
                child: Semantics(hint: hint, liveRegion: true, child: textEditor),
              );
      }

      // All sibling fields register before layout. Defer only the editor's
      // action choice so next/done is correct on the cold frame, without a
      // post-layout setState or an extra input/controller implementation.
      final field = _form == null ? editor(context) : LayoutBuilder(builder: (context, _) => editor(context));
      final contents = Row(
        crossAxisAlignment: multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          if (widget.leading case final leading?) ...[
            Padding(
              padding: EdgeInsets.only(top: multiLine ? geometry.verticalInset : 0),
              child: FrostIcon(leading, size: size.iconSize, color: tokens.textSecondary),
            ),
            SizedBox(width: gap),
          ],
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: geometry.verticalInset),
              child: Material(type: MaterialType.transparency, child: field),
            ),
          ),
          FrostFieldClearButton(visible: widget.clearable && _controller.text.isNotEmpty && enabled && !widget.readOnly, onClear: _clear),
          ?widget.trailing,
          if (widget._secure)
            TextFieldTapRegion(
              child: FrostButton.icon(
                icon: _passwordVisible ? FrostIconSet.of(context).eyeOff : FrostIconSet.of(context).eye,
                label: _passwordVisible ? FrostScope.labelsOf(context).hidePassword : FrostScope.labelsOf(context).showPassword,
                size: FrostControlSize.compact,
                onPressed: enabled
                    ? () {
                        setState(() => _passwordVisible = !_passwordVisible);
                        _focus.requestFocus();
                      }
                    : null,
              ),
            ),
        ],
      );
      return FrostFieldLayout(
        label: widget.label,
        help: widget.help,
        error: widget.error,
        supportingTrailing: options?.supportingTrailing,
        enabled: enabled,
        child: FrostFieldFrame(size: size, enabled: enabled, focused: _focus.hasFocus, invalid: invalid, multiline: multiLine, child: contents),
      );
    },
  );
}
