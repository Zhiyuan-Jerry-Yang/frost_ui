import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../feedback/inline_banner.dart';
import '../foundation/metrics.dart';
import '../foundation/typography.dart';
import '../motion/spring.dart';
import '../primitives/presence.dart';
import '../primitives/text.dart';
import '_form_submit.dart';

part '_form_scope.dart';

// Fields, titled sections and neighboring sections have separate rhythms.
const _formFieldGap = 12.0, _formSectionGap = 24.0, _formTitleGap = 8.0;

/// Submission and focus orchestration; field values and errors stay app-owned.
/// A controller can be attached to one form at a time. Unattached submission
/// fails with StateError, and application exceptions are propagated unchanged.
class FrostFormController extends ChangeNotifier {
  _FrostFormState? _owner;
  bool _disposed = false;

  /// Returns the same future while submission is in flight. Numeric editing
  /// is normalized first, waiting for active IME composition to finish.
  Future<bool> submit() => _owner?._submit() ?? Future<bool>.error(StateError('The form controller is not attached.'));
  void _attach(_FrostFormState owner) {
    if (_disposed) throw StateError('The form controller is disposed.');
    if (_owner != null && _owner != owner) throw StateError('A form controller can attach to only one form.');
    _owner = owner;
  }

  @override
  void dispose() {
    _disposed = true;
    _owner = null;
    super.dispose();
  }
}

/// Arranges fields and sections without owning their values or validation.
/// A rejected submission focuses and reveals the first app-supplied error
/// after the next frame. Unmounting prevents subsequent focus/scroll work.
class FrostForm extends StatefulWidget {
  const FrostForm({required this.children, required this.onSubmit, this.controller, this.errorSummary, super.key});
  final List<Widget> children;
  final FutureOr<bool> Function() onSubmit;
  final FrostFormController? controller;
  final String? errorSummary;
  @override
  State<FrostForm> createState() => _FrostFormState();
}

class _FrostFormState extends State<FrostForm> {
  late final _coordinator = FrostFormCoordinator(submit: _submitFromField);
  Future<bool>? _pending;
  String? _summary;
  @override
  void initState() {
    super.initState();
    _summary = widget.errorSummary;
  }

  @override
  void didUpdateWidget(FrostForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.errorSummary != null) _summary = widget.errorSummary;
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._owner == this) oldWidget.controller?._owner = null;
    }
  }

  @override
  void dispose() {
    if (widget.controller?._owner == this) widget.controller?._owner = null;
    _coordinator.dispose();
    super.dispose();
  }

  Future<bool> _submitFromField() => FrostFormSubmitScope.maybeOf(context)?.call() ?? _submit();

  Future<bool> _submit() {
    if (_pending case final pending?) return pending;
    final completion = Completer<bool>(), onSubmit = widget.onSubmit;
    final pending = _pending = completion.future;
    () async {
      try {
        for (final field in _coordinator.orderedFields) {
          if (!field.context.mounted) continue;
          if (!mounted || !await field.prepare()) {
            completion.complete(false);
            return;
          }
        }
        if (!mounted) {
          completion.complete(false);
          return;
        }
        final accepted = await onSubmit();
        if (!accepted && mounted) {
          // App setState/error updates must finish their next frame first.
          await WidgetsBinding.instance.endOfFrame;
          if (mounted) {
            final invalid = _coordinator.orderedFields.where((field) => field.hasError && field.canFocus).firstOrNull;
            if (invalid != null) {
              invalid.focus?.requestFocus();
              final duration = FrostMotion.duration(context, FrostMotion.standardDuration);
              final target = invalid.context;
              if (target.mounted) {
                await Scrollable.ensureVisible(target, duration: duration, curve: FrostSpringCurve(FrostMotion.standard, FrostMotion.standardDuration));
              }
            }
          }
        }
        completion.complete(accepted);
      } catch (error, stack) {
        completion.completeError(error, stack);
      } finally {
        if (identical(_pending, pending)) _pending = null;
      }
    }();
    return pending;
  }

  double _gapBefore(int index) =>
      widget.children[index] is FrostFormSection || widget.children[index - 1] is FrostFormSection ? _formSectionGap : _formFieldGap;

  @override
  Widget build(BuildContext context) {
    // Bind this UI-only association in the guarded build callback. Throwing
    // from initState/didUpdateWidget can interrupt focus subtree cleanup.
    // No listeners or application state are changed by the association.
    widget.controller?._attach(this);
    return FrostFormScope(
      coordinator: _coordinator,
      child: FocusTraversalGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FrostPresence(
              visible: widget.errorSummary != null,
              effect: FrostPresenceEffect.expand,
              alignment: AlignmentDirectional.topStart,
              child: Padding(
                padding: const EdgeInsets.only(bottom: _formSectionGap),
                child: FrostInlineBanner(tone: FrostBannerTone.negative, message: _summary ?? ''),
              ),
            ),
            for (final (index, child) in widget.children.indexed) ...[
              if (index > 0) SizedBox(height: _gapBefore(index)),
              FrostFormOrder(order: [index], child: child),
            ],
          ],
        ),
      ),
    );
  }
}

/// A titled form group with a common field rhythm and inherited focus order.
class FrostFormSection extends StatelessWidget {
  const FrostFormSection({this.title, required this.children, super.key});
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (title case final title?) ...[FrostText(title, role: FrostTextRole.headline, tone: FrostTextTone.primary), const SizedBox(height: _formTitleGap)],
      for (final (index, child) in children.indexed) ...[
        if (index > 0) const SizedBox(height: _formFieldGap),
        FrostFormOrder(order: [...FrostFormOrder.of(context), index], child: child),
      ],
    ],
  );
}
