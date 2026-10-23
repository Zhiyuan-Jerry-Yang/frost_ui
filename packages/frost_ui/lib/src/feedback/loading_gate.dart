import 'dart:async';
import 'package:flutter/widgets.dart';

/// Delays short waits, then keeps the shown loading state stable long enough
/// to read. Mounting while loading follows the same delay as later requests.
class FrostLoadingGate extends StatefulWidget {
  const FrostLoadingGate({required this.loading, required this.builder, super.key});
  final bool loading;
  final Widget Function(BuildContext context, bool showLoading) builder;
  @override
  State<FrostLoadingGate> createState() => _FrostLoadingGateState();
}

class _FrostLoadingGateState extends State<FrostLoadingGate> {
  // Avoid flashing a wait shorter than the shared loading delay.
  static const _showDelay = Duration(milliseconds: 300);
  // Once visible, a loading affordance must remain readable for this long.
  static const _minimumVisible = Duration(milliseconds: 400);
  Timer? _delay, _minimum;
  bool _shown = false, _minimumElapsed = false, _hasShown = false;
  @override
  void initState() {
    super.initState();
    if (widget.loading) _schedule();
  }

  void _schedule() {
    _delay?.cancel();
    _delay = Timer(_showDelay, () {
      if (!mounted || !widget.loading) return;
      setState(() {
        _shown = true;
        _hasShown = true;
        _minimumElapsed = false;
      });
      _minimum?.cancel();
      _minimum = Timer(_minimumVisible, () {
        if (!mounted) return;
        setState(() {
          _minimumElapsed = true;
          if (!widget.loading) _shown = false;
        });
      });
    });
  }

  @override
  void didUpdateWidget(FrostLoadingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading == oldWidget.loading) return;
    if (widget.loading) {
      if (!_shown) {
        _hasShown = false;
        _schedule();
      }
    } else {
      _delay?.cancel();
      if (_minimumElapsed) _shown = false;
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _minimum?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _LoadingPresentation(
    hasShown: _hasShown,
    child: Builder(builder: (context) => widget.builder(context, _shown)),
  );
}

// Internal history lets a result compose with the indicator that was actually
// visible. A request shorter than the gate must never introduce one afterwards.
class _LoadingPresentation extends InheritedWidget {
  const _LoadingPresentation({required this.hasShown, required super.child});
  final bool hasShown;
  @override
  bool updateShouldNotify(_LoadingPresentation oldWidget) => hasShown != oldWidget.hasShown;
}

bool frostLoadingHasShown(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_LoadingPresentation>()?.hasShown ?? true;
