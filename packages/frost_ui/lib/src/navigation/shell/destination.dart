part of 'shell.dart';

/// The retained destination page inside a [FrostShell]'s content Navigator.
///
/// Place this once around the root page that hosts primary destinations (for
/// example, a router's retained branch shell), rather than around the Navigator
/// itself or each branch. The bar and its target State remain mounted across
/// destination changes. Secondary routes cover the complete root page, including
/// its navigation, without resizing either route. Horizontal layouts reserve no
/// navigation height. The bar owns the root's bottom system safe area.
class FrostShellDestination extends StatelessWidget {
  const FrostShellDestination({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final navigation = context.dependOnInheritedWidgetOfExactType<_FrostDestinationNavigation>();
    assert(navigation != null, 'FrostShellDestination must be below FrostShell.');
    if (navigation == null) return child;
    return Column(
      children: [
        Expanded(
          child: MediaQuery.removePadding(context: context, removeBottom: navigation.enabled, child: child),
        ),
        if (navigation.enabled) navigation.navigation,
      ],
    );
  }
}

class _FrostDestinationNavigation extends InheritedWidget {
  const _FrostDestinationNavigation({required this.enabled, required this.navigation, required super.child});
  final bool enabled;
  final Widget navigation;
  @override
  bool updateShouldNotify(_FrostDestinationNavigation oldWidget) => enabled != oldWidget.enabled || navigation != oldWidget.navigation;
}
