import 'dart:async';
import 'package:flutter/widgets.dart';

/// Closes the containing panel normally, then executes [action] with the
/// still-mounted context that opened it. Use this for navigation from Sheet,
/// Dialog, Popover and Inspector content; do not retain the panel's context.
/// A nested panel closes only itself. Repeated requests during closure share
/// one operation. If the owner was removed, the action is discarded.
Future<void> closeFrostPanelThen(BuildContext context, FutureOr<void> Function(BuildContext origin) action) {
  final scope = context.getInheritedWidgetOfExactType<_PanelActionScope>();
  if (scope == null) throw StateError('closeFrostPanelThen requires Frost panel content.');
  return scope.run(action);
}

/// Library-owned action boundary; no global registration or Navigator observer.
class FrostPanelActionScope extends StatefulWidget {
  const FrostPanelActionScope({required this.origin, required this.close, required this.child, super.key});
  final BuildContext origin;
  final Future<bool> Function() close;
  final Widget child;
  @override
  State<FrostPanelActionScope> createState() => _PanelActionState();
}

class _PanelActionState extends State<FrostPanelActionScope> {
  Future<void>? _running;
  Future<void> run(FutureOr<void> Function(BuildContext) action) => _running ??= _run(action);
  Future<void> _run(FutureOr<void> Function(BuildContext) action) async {
    final origin = widget.origin;
    if (!await widget.close()) {
      _running = null;
      return;
    }
    if (origin.mounted) await action(origin);
  }

  @override
  Widget build(BuildContext context) => _PanelActionScope(run: run, child: widget.child);
}

class _PanelActionScope extends InheritedWidget {
  const _PanelActionScope({required this.run, required super.child});
  final Future<void> Function(FutureOr<void> Function(BuildContext)) run;
  @override
  bool updateShouldNotify(_PanelActionScope oldWidget) => run != oldWidget.run;
}
