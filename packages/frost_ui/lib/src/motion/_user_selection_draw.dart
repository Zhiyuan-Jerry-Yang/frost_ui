import 'package:flutter/widgets.dart';

// A pulse is valid for the value echo of one input frame only. Lazy remounts
// must not replay the last selected item's old animation provenance.
class FrostUserSelectionPulse {
  FrostUserSelectionPulse() {
    WidgetsBinding.instance.addPostFrameCallback((_) => active = false);
  }
  bool active = true;
}

bool frostFreshUserSelection(Object? trigger) => trigger is FrostUserSelectionPulse && trigger.active;

/// Internal provenance for marks driven by a shared selection controller.
class FrostUserSelectionTrigger extends InheritedWidget {
  const FrostUserSelectionTrigger({required this.trigger, required super.child, super.key});
  final Object? trigger;
  static Object? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostUserSelectionTrigger>()?.trigger;
  @override
  bool updateShouldNotify(FrostUserSelectionTrigger oldWidget) => trigger != oldWidget.trigger;
}

/// Records the controlled value echo of this input only. A later programmatic
/// update cannot accidentally replay a stale user action. No layout callback or
/// public animation flag is needed, and mounting never draws an entry stroke.
class FrostUserSelectionDraw extends StatefulWidget {
  const FrostUserSelectionDraw({required this.selected, required this.onActivate, required this.builder, this.trigger, this.trackInput = true, super.key});
  final bool? selected;
  final VoidCallback? onActivate;
  final Object? trigger;
  final bool trackInput;
  final Widget Function(BuildContext context, Object? trigger, VoidCallback? activate) builder;
  @override
  State<FrostUserSelectionDraw> createState() => _UserSelectionDrawState();
}

class _UserSelectionDrawState extends State<FrostUserSelectionDraw> {
  bool _pending = false;
  Object? _trigger;
  int _input = 0;
  void _activate() {
    final input = ++_input;
    _pending = widget.trackInput;
    widget.onActivate?.call();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && input == _input) _pending = false;
    });
  }

  @override
  void didUpdateWidget(FrostUserSelectionDraw oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      _trigger = _pending ? FrostUserSelectionPulse() : null;
      _pending = false;
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, widget.trigger ?? FrostUserSelectionTrigger.of(context) ?? _trigger, widget.onActivate == null ? null : _activate);
}
