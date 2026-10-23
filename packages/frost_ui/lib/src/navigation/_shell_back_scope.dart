import 'package:flutter/widgets.dart';

/// Internal bridge for compact panes whose Navigator lives below the shell.
/// The outer route's canGoBack alone cannot describe those local details.
class FrostShellBackHost extends StatefulWidget {
  const FrostShellBackHost({required this.canGoBack, required this.onBack, required this.builder, super.key});
  final bool canGoBack;
  final VoidCallback onBack;
  final Widget Function(BuildContext context, bool canGoBack, VoidCallback goBack) builder;
  @override
  State<FrostShellBackHost> createState() => _BackHostState();
}

class _BackHostState extends State<FrostShellBackHost> {
  final _targets = <_BackTargetState>{};
  void update(_BackTargetState target, bool enabled) {
    if (!mounted || _targets.contains(target) == enabled) return;
    setState(() {
      if (enabled) {
        _targets.add(target);
      } else {
        _targets.remove(target);
      }
    });
  }

  Iterable<_BackTargetState> get activeTargets => _targets.where((target) => target.active);
  void back() {
    final targets = activeTargets;
    if (targets.isNotEmpty) {
      targets.last.widget.onBack();
    } else if (widget.canGoBack) {
      widget.onBack();
    }
  }

  @override
  Widget build(BuildContext context) => _BackRegistry(
    host: this,
    child: Builder(builder: (context) => widget.builder(context, widget.canGoBack || activeTargets.isNotEmpty, back)),
  );
}

class _BackRegistry extends InheritedWidget {
  const _BackRegistry({required this.host, required super.child});
  final _BackHostState host;
  static _BackHostState? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_BackRegistry>()?.host;
  @override
  bool updateShouldNotify(_BackRegistry oldWidget) => host != oldWidget.host;
}

/// Registration follows route/lifecycle notifications after the current frame;
/// it never writes ancestor State from build or disposal. The target only
/// controls local navigation and does not change the app's route stack.
class FrostShellBackTarget extends StatefulWidget {
  const FrostShellBackTarget({required this.enabled, required this.onBack, required this.child, super.key});
  final bool enabled;
  final VoidCallback onBack;
  final Widget child;
  @override
  State<FrostShellBackTarget> createState() => _BackTargetState();
}

class _BackTargetState extends State<FrostShellBackTarget> {
  _BackHostState? _host;
  bool _queued = false;
  final _routes = <ModalRoute<Object?>>[];
  bool get active => mounted && widget.enabled && _routes.every((route) => route.isCurrent);
  void _routeChanged(AnimationStatus _) => _publish();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final host = _BackRegistry.of(context);
    if (host != _host) {
      final old = _host;
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.update(this, false));
      _host = host;
    }
    for (final route in _routes) {
      route.secondaryAnimation?.removeStatusListener(_routeChanged);
    }
    _routes.clear();
    // A branch Navigator can still call its page current after an enclosing
    // route is covered. Track every owning route, including across Navigators.
    for (var route = ModalRoute.of<Object?>(context); route != null;) {
      if (_routes.contains(route)) break;
      _routes.add(route);
      route.secondaryAnimation?.addStatusListener(_routeChanged);
      final navigator = route.navigator;
      route = navigator == null ? null : ModalRoute.of<Object?>(navigator.context);
    }
    _publish();
  }

  @override
  void didUpdateWidget(FrostShellBackTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _publish();
  }

  void _publish() {
    if (_queued) return;
    _queued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _queued = false;
      if (mounted) _host?.update(this, active);
    });
  }

  @override
  void dispose() {
    for (final route in _routes) {
      route.secondaryAnimation?.removeStatusListener(_routeChanged);
    }
    final host = _host;
    WidgetsBinding.instance.addPostFrameCallback((_) => host?.update(this, false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
