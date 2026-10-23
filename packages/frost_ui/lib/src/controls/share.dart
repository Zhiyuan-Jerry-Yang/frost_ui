import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/icon_data.dart';
import '../foundation/scope.dart';
import 'buttons.dart';
import 'toast.dart';

/// Invokes the host's platform share integration, or copies [text] and shows
/// the shared clipboard notice when no integration is supplied.
class FrostShare extends StatefulWidget {
  const FrostShare({required this.text, required this.label, this.onShare, this.icon, super.key});
  final String text, label;
  final Future<void> Function(String text)? onShare;
  final FrostIconData? icon;
  @override
  State<FrostShare> createState() => _ShareState();
}

class _ShareState extends State<FrostShare> {
  bool _busy = false;
  Future<void> _share() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final share = widget.onShare;
      if (share != null) {
        await share(widget.text);
      } else {
        await Clipboard.setData(ClipboardData(text: widget.text));
        if (mounted) FrostToast.copied(FrostScope.labelsOf(context).copied);
      }
    } catch (error, stack) {
      if (mounted) FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      FrostButton.icon(icon: widget.icon ?? FrostIconSet.of(context).share, label: widget.label, onPressed: _share, loading: _busy);
}
