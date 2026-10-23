import 'dart:ui' show SemanticsHitTestBehavior;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/_layout_scope.dart';
import '../foundation/control_scope.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../motion/_material_reveal.dart';
import '../motion/spring.dart';
import 'panel_action.dart';

// Dialogs grow very slightly; sheets travel from their bottom edge.
const _dialogInitialScale = .96;

class FrostModalRouteScope extends InheritedWidget {
  const FrostModalRouteScope({required this.barrierDismissible, required this.compact, required super.child, super.key});
  final bool barrierDismissible, compact;

  static FrostModalRouteScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostModalRouteScope>();

  @override
  bool updateShouldNotify(FrostModalRouteScope oldWidget) => barrierDismissible != oldWidget.barrierDismissible || compact != oldWidget.compact;
}

Future<T?> pushFrostModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required bool barrierDismissible,
  Color? barrierColor,
  bool useRootNavigator = true,
  bool bottomSheet = false,
}) async {
  final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  final config = FrostScope.configOf(context);
  final solid = FrostScope.maybeOf(context)?.reduceTransparency ?? false;
  final sourceMedia = MediaQuery.of(context);
  final compact = FrostSizeClass.of(context) == FrostSizeClass.compact;
  final origin = FocusManager.instance.primaryFocus;
  final originContext = context;
  try {
    late final _FrostModalRoute<T> route;
    route = _FrostModalRoute<T>(
      bottomSheet: bottomSheet,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor ?? DialogTheme.of(context).barrierColor ?? FrostThemeTokens.of(context).onMediaScrim,
      barrierLabel: FrostScope.labelsOf(context).dismiss,
      pageBuilder: (routeContext, _, _) => themes.wrap(
        FrostScope(
          config: config,
          reduceTransparency: solid,
          child: Builder(
            builder: (context) => MediaQuery(
              // Keyboard and window metrics remain live while local reading
              // and accessibility preferences cross the route boundary.
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: sourceMedia.textScaler, highContrast: sourceMedia.highContrast, disableAnimations: sourceMedia.disableAnimations),
              child: FrostModalRouteScope(
                compact: compact,
                barrierDismissible: barrierDismissible,
                child: FrostControlScope(
                  size: FrostControlSize.regular,
                  toolbar: false,
                  enabled: true,
                  child: FocusTraversalGroup(
                    policy: ReadingOrderTraversalPolicy(),
                    child: Focus(
                      onKeyEvent: (node, event) {
                        if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return KeyEventResult.ignored;
                        if (barrierDismissible) Navigator.of(node.context!).pop();
                        return KeyEventResult.handled;
                      },
                      child: Semantics(
                        scopesRoute: true,
                        explicitChildNodes: true,
                        hitTestBehavior: SemanticsHitTestBehavior.opaque,
                        child: FrostPanelActionScope(
                          origin: originContext,
                          close: () async {
                            if (!route.isCurrent) return false;
                            navigator.pop<T>();
                            await route.completed;
                            return true;
                          },
                          child: bottomSheet ? Builder(builder: builder) : SafeArea(child: Builder(builder: builder)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return await navigator.push<T>(route);
  } finally {
    if (origin != null && origin.context != null && origin.canRequestFocus) origin.requestFocus();
  }
}

class _FrostModalRoute<T> extends RawDialogRoute<T> {
  _FrostModalRoute({
    required this.bottomSheet,
    required super.pageBuilder,
    required super.barrierDismissible,
    required super.barrierColor,
    required super.barrierLabel,
  }) : super(transitionDuration: bottomSheet ? FrostMotion.standardDuration : FrostMotion.page, traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop);

  final bool bottomSheet;
  final _glass = FrostRevealHandle();
  late final _fade = CurvedAnimation(parent: animation!, curve: Curves.easeOut, reverseCurve: bottomSheet ? Curves.easeInCubic : null);
  late final _movement = CurvedAnimation(
    parent: animation!,
    curve: FrostSpringCurve(bottomSheet ? FrostMotion.standard : FrostMotion.snappy, transitionDuration),
    reverseCurve: Curves.easeInCubic,
  );

  @override
  Duration get reverseTransitionDuration =>
      (bottomSheet ? FrostMotion.exit : FrostMotion.dismiss) + (_glass.hasNestedGlass && _glass.nestedProgress > 0 ? frostNestedGlassDuration : Duration.zero);

  @override
  Simulation? createSimulation({required bool forward}) =>
      forward ? null : frostGlassExitSimulation(_glass, controller!.value, bottomSheet ? FrostMotion.exit : FrostMotion.dismiss);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final fade = FrostMaterialRevealTransition(opacity: _fade, handle: _glass, contentOnly: true, child: child);
    if (MediaQuery.disableAnimationsOf(context)) return fade;
    return bottomSheet
        ? fade
        : ScaleTransition(
            scale: _movement.drive(Tween(begin: _dialogInitialScale, end: 1.0)),
            child: fade,
          );
  }

  @override
  void dispose() {
    _fade.dispose();
    _movement.dispose();
    super.dispose();
  }
}
