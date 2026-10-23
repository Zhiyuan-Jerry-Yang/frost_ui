import '../primitives/_page_outline.dart';
import 'package:flutter/material.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/auto_scaffold.dart';
import '../layout/content_viewport.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';
import '../primitives/text.dart';
import 'shell_navigation_scope.dart';
import 'toolbar.dart';
import '_page_header_leading.dart';
import 'toolbar_menu_button.dart';

/// Page-owned navigation, title and actions in one adaptive toolbar row.
class FrostPageHeader extends StatelessWidget {
  const FrostPageHeader({
    this.leading = const [],
    this.controls = const [],
    this.title,
    this.middle,
    this.collapsedMiddle,
    this.middleMaxWidth = 360,
    this.actions = const [],
    this.onBack,
    super.key,
  }) : assert(middleMaxWidth > 0 && middleMaxWidth < double.infinity);

  /// Natural-width controls after automatic back and before the title. Leading
  /// menus truncate before a source/title menu; trailing actions keep their own
  /// width. Truncated menus retain full tooltips and semantic labels.
  final List<Widget> leading;

  /// Priority-aware choices after leading content; shares overflow with actions.
  /// Flexible search fields continue to use middle/middleMaxWidth.
  final List<FrostToolbarItem> controls;
  final Widget? title, middle, collapsedMiddle;

  /// Forwarded to [FrostToolbar.middleMaxWidth]. This changes only the middle
  /// slot's growth limit; header height and action/overflow rules are unchanged.
  final double middleMaxWidth;
  final List<FrostToolbarItem> actions;
  final VoidCallback? onBack;
  static const horizontalHeight = 52.0;
  static const verticalHeight = 48.0;

  static Widget? leadingFor(BuildContext context, {VoidCallback? onBack}) {
    if (FrostPageHeaderLeading.of(context) case final override?) return override.leading;
    final navigation = FrostShellNavigationScope.maybeOf(context);
    if (navigation?.ownsBackControl ?? false) return null;
    var route = ModalRoute.of(context);
    if (navigation != null) {
      // A retained branch can remain current in its own Navigator while an
      // enclosing page is covered. Only the visible chain owns shell Back.
      final visited = <ModalRoute<Object?>>{};
      while (route != null && visited.add(route)) {
        if (!route.isCurrent) return null;
        final owner = route.navigator;
        route = owner == null ? null : ModalRoute.of(owner.context);
      }
      return navigation.canGoBack ? FrostCompactBackButton(onPressed: navigation.goBack) : null;
    }
    if (onBack != null) return FrostCompactBackButton(onPressed: onBack);
    final navigator = Navigator.maybeOf(context);
    final ownRoute = ModalRoute.of(context);
    final dismisses = ownRoute?.impliesAppBarDismissal ?? navigator?.canPop() ?? false;
    return navigator != null && dismisses ? FrostCompactBackButton(onPressed: () => navigator.maybePop()) : null;
  }

  @override
  Widget build(BuildContext context) {
    final height = FrostAutoScaffold.usesHorizontalLayoutOf(context) ? horizontalHeight : verticalHeight;
    final scaler = MediaQuery.textScalerOf(context);
    final headline = FrostTypography.of(context).style(FrostTextRole.headline);
    final fontSize = headline.fontSize!;
    final extraLine = (scaler.scale(fontSize) - fontSize * 1.3) * headline.height!;
    final scales = extraLine > 0;
    final back = leadingFor(context, onBack: onBack);
    Widget row = FrostToolbar(
      leading: [
        ?back,
        ...leading,
        if (title != null) FrostToolbarTitle(child: title!),
      ],
      controls: controls,
      middle: middle,
      middleMaxWidth: middleMaxWidth,
      collapsedMiddle: collapsedMiddle,
      trailing: actions,
    );
    final keyline = FrostKeyline.maybeOf(context);
    if (keyline == null || keyline.insideContainer) {
      final inset = FrostGap.of(context).page;
      row = FrostKeyline(
        leadingRoom: inset,
        trailingRoom: inset,
        edgeDistanceStart: inset,
        edgeDistanceEnd: inset,
        insideContainer: false,
        contentStart: inset,
        child: Padding(
          padding: EdgeInsets.only(left: inset, right: inset + FrostPageOutline.channelOf(context)),
          child: row,
        ),
      );
    }
    return DefaultTextStyle(
      style: FrostTypography.of(context).style(FrostTextRole.headline).copyWith(color: FrostThemeTokens.of(context).textPrimary),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: scales ? height + extraLine : height, maxHeight: scales ? double.infinity : height),
        child: row,
      ),
    );
  }
}

class FrostCompactBackButton extends StatelessWidget {
  const FrostCompactBackButton({required this.onPressed, super.key});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) =>
      FrostToolbarControl(label: FrostScope.labelsOf(context).back, icon: FrostIconSet.of(context).back, showsLabel: false, onPressed: onPressed);
}

class FrostInlinePageHeading extends StatelessWidget {
  const FrostInlinePageHeading({required this.title, this.actions = const [], this.maxWidth = FrostMetrics.contentMaxWidth, super.key});
  final String title;
  final List<Widget> actions;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => FrostContentColumn(
    maxWidth: maxWidth,
    child: Padding(
      padding: const EdgeInsets.only(top: FrostGap.inline),
      child: Row(
        children: [
          Expanded(
            child: FrostText(title, role: FrostTextRole.title1, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ...actions,
        ],
      ),
    ),
  );
}
