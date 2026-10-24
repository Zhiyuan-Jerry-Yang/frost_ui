import 'dart:async';

import 'package:flutter/widgets.dart';

/// Route-local Back, distinct from Flutter's barrier dismissal action. A page
/// that handles Back itself (for example to close a search field first)
/// registers an [Action] for it.
class FrostBackIntent extends Intent {
  const FrostBackIntent();
}

/// Performs one Back step from [context] (or the primary focus): leaves an
/// active text field, then a local [FrostBackIntent] action, then a modal's
/// [DismissIntent], then the nearest Navigator. Returns whether anything
/// handled it.
bool requestFrostBack({BuildContext? context}) {
  final focus = FocusManager.instance.primaryFocus;
  final target = context ?? focus?.context;
  if (target == null || !target.mounted) return false;
  if (focus?.context?.findAncestorStateOfType<EditableTextState>() != null) {
    focus?.unfocus();
    return true;
  }
  const back = FrostBackIntent();
  final local = Actions.maybeFind<FrostBackIntent>(target);
  if (local != null) {
    // A disabled local action blocks navigation, for example during an
    // operation that must not be left. Do not bypass it by popping an
    // enclosing Navigator instead.
    if (local.isEnabled(back)) Actions.invoke(target, back);
    return true;
  }
  const dismiss = DismissIntent();
  final modal = Actions.maybeFind<DismissIntent>(target);
  if (modal != null && modal.isEnabled(dismiss)) {
    Actions.invoke(target, dismiss);
    return true;
  }
  final navigator = Navigator.maybeOf(target);
  if (navigator == null) return false;
  unawaited(navigator.maybePop());
  return true;
}
