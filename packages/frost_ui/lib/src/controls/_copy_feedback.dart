import 'dart:async';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../primitives/icon.dart';
import '_button_control.dart';
import '_button_types.dart';

// Successful clipboard feedback lasts independently of the icon crossfade.
const _copiedDuration = Duration(milliseconds: 1500);

/// Library-only clipboard lifecycle shared by CodeBlock and Copyable.
class FrostCopyFeedback extends StatefulWidget {
  const FrostCopyFeedback({required this.text, required this.builder, this.enabled = true, super.key});
  final String text;
  final bool enabled;
  final Widget Function(BuildContext context, bool copied, VoidCallback copy) builder;
  @override
  State<FrostCopyFeedback> createState() => _CopyFeedbackState();
}

class _CopyFeedbackState extends State<FrostCopyFeedback> {
  Timer? _reset;
  bool _copied = false;
  int _operation = 0;
  Future<void> _copy() async {
    if (!widget.enabled) return;
    final operation = ++_operation;
    try {
      await Clipboard.setData(ClipboardData(text: widget.text));
    } catch (error, stack) {
      if (mounted && operation == _operation) FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
      return;
    }
    if (!mounted || operation != _operation) return;
    _reset?.cancel();
    setState(() => _copied = true);
    unawaited(SemanticsService.sendAnnouncement(View.of(context), FrostScope.labelsOf(context).copied, Directionality.of(context)));
    _reset = Timer(_copiedDuration, () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void didUpdateWidget(FrostCopyFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.enabled != widget.enabled) {
      _operation++;
      _reset?.cancel();
      _copied = false;
    }
  }

  @override
  void dispose() {
    _operation++;
    _reset?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _copied, _copy);
}

class FrostCopyFeedbackButton extends StatelessWidget {
  const FrostCopyFeedbackButton({required this.copied, required this.onCopy, super.key});
  final bool copied;
  final VoidCallback onCopy;
  @override
  Widget build(BuildContext context) {
    final icons = FrostIconSet.of(context);
    return FrostButtonControl(
      label: FrostScope.labelsOf(context).copy,
      onPressed: onCopy,
      size: FrostControlSize.compact,
      icon: icons.copy,
      iconStyle: FrostIconButtonStyle.plain,
      iconWidget: AnimatedSwitcher(
        duration: FrostMotion.duration(context, FrostMotion.hover),
        child: FrostIcon(copied ? icons.check : icons.copy, key: ValueKey(copied), size: FrostControlSize.compact.iconSize),
      ),
    );
  }
}
