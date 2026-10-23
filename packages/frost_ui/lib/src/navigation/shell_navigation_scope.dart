import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// The horizontal shell owns ordinary page back; vertical layouts use page headers.
class FrostShellNavigationScope extends InheritedWidget {
  const FrostShellNavigationScope({
    required this.ownsBackControl,
    required this.canGoBack,
    required this.goBack,
    required this.primaryReselection,
    required super.child,
    this.floatingChrome = true,
    super.key,
  });

  /// True when a horizontal shell supplies the fixed Back control. Page headers
  /// and custom page navigation must omit their ordinary Back in that case.
  /// A standalone route outside the shell still owns its own close/back control.
  final bool ownsBackControl;
  final bool canGoBack;
  final VoidCallback goBack;

  /// The destination index tapped again while already selected, with a
  /// sequence number so repeated taps are distinct events.
  final ValueListenable<({int index, int sequence})> primaryReselection;

  /// Whether pinned page bars float as rounded panels beside the sidebar,
  /// from the shell's sidebar style.
  final bool floatingChrome;

  static FrostShellNavigationScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostShellNavigationScope>();

  @override
  bool updateShouldNotify(FrostShellNavigationScope oldWidget) =>
      ownsBackControl != oldWidget.ownsBackControl ||
      canGoBack != oldWidget.canGoBack ||
      goBack != oldWidget.goBack ||
      primaryReselection != oldWidget.primaryReselection ||
      floatingChrome != oldWidget.floatingChrome;
}
