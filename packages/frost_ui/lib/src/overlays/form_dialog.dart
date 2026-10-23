import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../controls/_form_submit.dart';
import '../controls/buttons.dart';
import '../controls/form.dart';
import '../foundation/scope.dart';
import 'adaptive_panel.dart';
import 'dialogs.dart';

/// The caller owns this controller and must dispose it after its dialog closes.
/// A controller can be attached to at most one dialog at a time. Field values
/// and field errors remain owned by the stateful widgets supplied in sections.
class FrostFormDialogController extends ChangeNotifier {
  FrostFormDialogController({String? errorSummary}) : _errorSummary = errorSummary, _notifiedSummary = errorSummary;
  String? _errorSummary, _notifiedSummary;
  Object? _owner;
  bool _disposed = false, _scheduled = false;

  String? get errorSummary => _errorSummary;
  set errorSummary(String? value) {
    assert(!_disposed);
    if (_errorSummary == value) return;
    _errorSummary = value;
    // A caller may discover an error while building a field. Do not notify
    // another subtree in that build stack; coalesce to the end of this frame.
    if (_owner != null && SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_scheduled) return;
      _scheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scheduled = false;
        if (!_disposed) _notify();
      });
    } else {
      _notify();
    }
  }

  void _notify() {
    if (_notifiedSummary == _errorSummary) return;
    _notifiedSummary = _errorSummary;
    notifyListeners();
  }

  void _attach(Object owner) {
    assert(!_disposed);
    assert(_owner == null || identical(_owner, owner), 'A form dialog controller can attach to only one dialog.');
    _owner = owner;
  }

  void _detach(Object owner) {
    if (identical(_owner, owner)) _owner = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _owner = null;
    super.dispose();
  }
}

/// Composes the shared dialog and form. True accepts and closes; false leaves
/// the dialog open and focuses its first app-supplied field error.
///
/// When [controller] is provided it is the sole summary source. Otherwise
/// [errorSummary] initializes a dialog-owned controller. Cancellation, Escape
/// and barrier dismissal return false; async loading uses the dialog's gate.
/// The optional leadingAction uses the same contract as FrostDialog.leadingAction:
/// plain, with semantic role ink, and no built-in confirmation.
/// [showsCloseButton] forwards the shared dialog close control; closing returns
/// false and discards any later result from an in-flight submission.
Future<bool> showFrostFormDialog({
  required BuildContext context,
  required String title,
  required List<Widget> sections,
  required FutureOr<bool> Function() onSubmit,
  required String submitLabel,
  String? cancelLabel,
  String? errorSummary,
  FrostDialogSize size = FrostDialogSize.regular,
  FrostFormDialogController? controller,
  FrostDialogAction<bool>? leadingAction,
  bool showsCloseButton = false,
}) async {
  final cancel = cancelLabel ?? FrostScope.labelsOf(context).cancel;
  return await showFrostAdaptiveDialog<bool>(
        context: context,
        builder: (_) => _FormDialog(
          title: title,
          sections: sections,
          onSubmit: onSubmit,
          submitLabel: submitLabel,
          cancelLabel: cancel,
          errorSummary: errorSummary,
          size: size,
          controller: controller,
          leadingAction: leadingAction,
          showsCloseButton: showsCloseButton,
        ),
      ) ??
      false;
}

class _FormDialog extends StatefulWidget {
  const _FormDialog({
    required this.title,
    required this.sections,
    required this.onSubmit,
    required this.submitLabel,
    required this.cancelLabel,
    required this.errorSummary,
    required this.size,
    required this.controller,
    required this.leadingAction,
    required this.showsCloseButton,
  });
  final String title, submitLabel, cancelLabel;
  final bool showsCloseButton;
  final List<Widget> sections;
  final FutureOr<bool> Function() onSubmit;
  final String? errorSummary;
  final FrostDialogSize size;
  final FrostFormDialogController? controller;
  final FrostDialogAction<bool>? leadingAction;
  @override
  State<_FormDialog> createState() => _FormDialogState();
}

class _FormDialogState extends State<_FormDialog> {
  final _form = FrostFormController();
  late final _summary = widget.controller ?? FrostFormDialogController(errorSummary: widget.errorSummary);
  @override
  void dispose() {
    _summary._detach(this);
    if (widget.controller == null) _summary.dispose();
    _form.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Like FrostForm, bind in the guarded build callback rather than initState.
    // This association does not notify listeners or change application state.
    _summary._attach(this);
    return FrostDialog(
      title: widget.title,
      size: widget.size,
      leadingAction: widget.leadingAction,
      showsCloseButton: widget.showsCloseButton,
      content: Builder(
        builder: (context) => FrostFormSubmitScope(
          submit: () async {
            await FrostDialogSubmitScope.of(context)();
            return false;
          },
          child: ListenableBuilder(
            listenable: _summary,
            builder: (_, _) => FrostForm(controller: _form, errorSummary: _summary.errorSummary, onSubmit: widget.onSubmit, children: widget.sections),
          ),
        ),
      ),
      actions: [
        FrostDialogAction<bool>(label: widget.cancelLabel, role: FrostButtonRole.cancel, value: false),
        FrostDialogAction<bool>(label: widget.submitLabel, isDefault: true, value: true, onPressed: _form.submit),
      ],
    );
  }
}
