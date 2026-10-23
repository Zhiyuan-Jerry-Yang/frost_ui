import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controls/_button_control.dart';
import '../controls/_field_options.dart';
import '../controls/buttons.dart';
import '../controls/text_field.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/icon_data.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../layout/content_viewport.dart';
import '../primitives/_scroll_edge_fade.dart';
import '../primitives/media_frame.dart';
import '../primitives/presence.dart';
import '../primitives/text.dart';

// Attachments are fixed previews, independent of the editor's text scale.
const _attachmentExtent = 56.0;
// The removal circle sits four points inside the preview, with a full hit box.
const _attachmentRemoveDiameter = 20.0;
const _attachmentRemoveIcon = 12.0;
const _attachmentRemoveInset = 4.0;
const _maximumLines = 6;
const _countThreshold = .8;

@immutable
class FrostComposerAttachment {
  const FrostComposerAttachment({required this.thumbnail, required this.label, required this.onRemove});
  final Widget thumbnail;
  final String label;
  final VoidCallback onRemove;
}

/// A normal bottom layout slot, for example:
/// Column(children: [Expanded(child: messages), FrostComposer(...)]).
/// It occupies its actual animated height and accounts for bottom safe area
/// and keyboard insets. Avoid adding a second keyboard inset around this slot.
///
/// The application owns text, attachments and reply identity. onSend receives
/// a click-time text snapshot (an empty string for attachment-only messages). Completion never clears or overwrites the editor;
/// the application must use its request identity when deciding what to clear.
/// While sending, text and tools stay editable; attachment removal and reply
/// cancellation are disabled because those belong to the sending message.
/// Exceptions retain input, restore send availability, and report FlutterError;
/// the application supplies error feedback through a toast or InlineBanner.
class FrostComposer extends StatefulWidget {
  const FrostComposer({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onSend,
    this.maxLength,
    this.attachments = const [],
    this.tools = const [],
    this.replyingTo,
    this.onCancelReply,
    this.sending = false,
    super.key,
  }) : assert(maxLength == null || maxLength > 0);
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final FutureOr<void> Function(String text) onSend;
  final int? maxLength;
  final List<FrostComposerAttachment> attachments;
  final List<Widget> tools;
  final Widget? replyingTo;
  final VoidCallback? onCancelReply;
  final bool sending;
  @override
  State<FrostComposer> createState() => _ComposerState();
}

class _ComposerState extends State<FrostComposer> {
  final _attachments = ScrollController();
  bool _sending = false;
  bool get _busy => _sending || widget.sending;
  int get _count => widget.controller.text.characters.length;
  bool get _overLimit => widget.maxLength != null && _count > widget.maxLength!;
  bool get _canSend => !_busy && !_overLimit && (widget.controller.text.trim().isNotEmpty || widget.attachments.isNotEmpty);
  bool get _composing => widget.controller.value.composing.isValid && !widget.controller.value.composing.isCollapsed;
  Future<void> _send() async {
    if (!_canSend || _composing) return;
    final text = widget.controller.text.trim().isEmpty ? '' : widget.controller.text;
    setState(() => _sending = true);
    try {
      await widget.onSend(text);
    } catch (error, stack) {
      if (mounted) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack, library: 'frost_ui', context: ErrorDescription('while sending composer text')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.enter || HardwareKeyboard.instance.isShiftPressed || _composing) {
      return KeyEventResult.ignored;
    }
    final desktop = switch (Theme.of(context).platform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };
    if (!desktop) return KeyEventResult.ignored;
    unawaited(_send());
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _attachments.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final labels = FrostScope.labelsOf(context);
      final icons = FrostIconSet.of(context);
      final media = MediaQuery.of(context);
      final countVisible = widget.maxLength != null && _count >= widget.maxLength! * _countThreshold;
      final compact = FrostControlSize.compact;
      final height = compact.height(context);
      final removeHit = FrostDensity.of(context).targetHeight;
      final removeCentre = _attachmentRemoveInset + _attachmentRemoveDiameter / 2;
      final removeOutset = math.max(0.0, removeHit / 2 - removeCentre);
      return Padding(
        padding: EdgeInsets.only(bottom: math.max(media.viewInsets.bottom, media.viewPadding.bottom)),
        child: FrostContentColumn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.replyingTo case final reply?) ...[
                Row(
                  children: [
                    Expanded(child: reply),
                    FrostButton.icon(icon: icons.close, label: labels.close, size: compact, onPressed: _busy ? null : widget.onCancelReply),
                  ],
                ),
                const SizedBox(height: FrostGap.related),
              ],
              if (widget.attachments.isNotEmpty) ...[
                SizedBox(
                  height: _attachmentExtent + removeOutset,
                  child: FrostScrollEdgeFade(
                    controller: _attachments,
                    child: ListView.separated(
                      controller: _attachments,
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.attachments.length,
                      separatorBuilder: (_, index) => const SizedBox(width: FrostGap.related),
                      itemBuilder: (context, index) {
                        final attachment = widget.attachments[index];
                        return SizedBox(
                          width: _attachmentExtent + removeOutset,
                          child: Stack(
                            children: [
                              PositionedDirectional(
                                top: removeOutset,
                                start: 0,
                                width: _attachmentExtent,
                                height: _attachmentExtent,
                                child: Semantics(
                                  image: true,
                                  label: attachment.label,
                                  child: FrostMediaFrame(radius: FrostRadius.sm, child: attachment.thumbnail),
                                ),
                              ),
                              PositionedDirectional(
                                top: 0,
                                end: 0,
                                child: FrostButtonControl(
                                  icon: icons.close,
                                  label: labels.remove,
                                  showsLabel: false,
                                  size: compact,
                                  iconStyle: FrostIconButtonStyle.onMedia,
                                  onPressed: _busy ? null : attachment.onRemove,
                                  geometry: const FrostButtonGeometry(
                                    horizontalInset: 0,
                                    verticalInset: 0,
                                    minimumWidth: _attachmentRemoveDiameter,
                                    visualHeight: _attachmentRemoveDiameter,
                                    iconSize: _attachmentRemoveIcon,
                                    cornerRadius: _attachmentRemoveDiameter / 2,
                                    alignment: MainAxisAlignment.center,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: FrostGap.related),
              ],
              Focus(
                onKeyEvent: _key,
                child: FrostFieldOptions(
                  appearance: FrostFieldAppearance.composer,
                  child: FrostTextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    placeholder: widget.placeholder,
                    size: FrostControlSize.regular,
                    minLines: 1,
                    maxLines: _maximumLines,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
              ),
              const SizedBox(height: FrostGap.related),
              FrostControlScope(
                size: compact,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: FrostGap.related,
                  runSpacing: FrostGap.related,
                  children: [
                    Wrap(spacing: FrostGap.related, children: widget.tools),
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: FrostGap.related,
                      runSpacing: FrostGap.related,
                      children: [
                        FrostPresence(
                          visible: countVisible,
                          effect: FrostPresenceEffect.expand,
                          axis: Axis.horizontal,
                          child: FrostText(
                            widget.maxLength == null ? '' : labels.characterCount(_count, widget.maxLength!),
                            role: FrostTextRole.footnote,
                            tone: _overLimit ? FrostTextTone.negative : FrostTextTone.tertiary,
                            numeric: true,
                          ),
                        ),
                        FrostButtonControl(
                          label: labels.send,
                          icon: icons.send,
                          variant: FrostButtonVariant.prominent,
                          showsLabel: false,
                          size: compact,
                          loading: _busy,
                          onPressed: _canSend ? _send : null,
                          geometry: FrostButtonGeometry(
                            horizontalInset: (height - compact.iconSize) / 2,
                            minimumWidth: height,
                            verticalInset: 0,
                            alignment: MainAxisAlignment.center,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
