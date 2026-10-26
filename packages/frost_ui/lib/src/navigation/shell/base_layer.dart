part of 'shell.dart';

class _ShellBase extends StatelessWidget {
  const _ShellBase({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) => enabled ? FrostSurface(role: FrostSurfaceRole.base, child: child) : child;
}

typedef FrostSidebarFrameBuilder = Widget Function(BuildContext context, Widget navigation);

/// How a navigation item marks its state.
enum FrostNavItemForm {
  /// A square icon tile expands into a labelled row; selection fills it.
  tile,

  /// Collapsed: the icon alone, its label in a tooltip. Expanded: icon and
  /// label in a row. Selection is a bar on the sidebar's edge and accent ink.
  indicator,
}

/// The outer form of the desktop sidebar. Every form shares the navigation
/// items, their spring, the More menu and the geometry; a form decides the
/// frame around them, how far it sits from the window edges, how items mark
/// their state and how the page's pinned bars sit beside it.
@immutable
sealed class FrostSidebarStyle {
  const FrostSidebarStyle();
  const factory FrostSidebarStyle.inset() = _FrostInsetSidebar;

  /// A floating glass capsule with a margin from the window edges.
  const factory FrostSidebarStyle.capsule() = FrostCapsuleSidebar;

  /// A full-height panel flush with the window's left edge: square corners,
  /// a solid surface and a hairline towards the content. Where the window is
  /// too narrow to push the page aside it still expands, over the page.
  const factory FrostSidebarStyle.flush({FrostNavItemForm itemForm}) = FrostFlushSidebar;

  /// A frame of the app's own. [outerMargin] is the distance from the window's
  /// left, top and bottom edges; [gutter] the gap to the page.
  const factory FrostSidebarStyle.custom({
    required EdgeInsets outerMargin,
    required double gutter,
    required FrostSidebarFrameBuilder frameBuilder,
    FrostNavItemForm itemForm,
    bool expandsOverContent,
  }) = FrostCustomSidebar;

  EdgeInsets margin(BuildContext context);
  double get gutter;
  Widget frame(BuildContext context, Widget navigation);
  FrostNavItemForm get itemForm;

  /// Whether the sidebar may expand over the page where the window is too
  /// narrow to make room for it; otherwise it stays collapsed there.
  bool get expandsOverContent;

  /// Whether pinned page bars float as rounded panels beside the sidebar
  /// (see [FrostPinnedChromeGlass]) rather than sitting flush.
  bool get floatingChrome;
}

final class FrostCapsuleSidebar extends FrostSidebarStyle {
  const FrostCapsuleSidebar();

  @override
  FrostNavItemForm get itemForm => FrostNavItemForm.tile;

  @override
  bool get expandsOverContent => false;

  @override
  bool get floatingChrome => true;

  static const _margin = 8.0;

  @override
  EdgeInsets margin(BuildContext context) {
    return const EdgeInsets.fromLTRB(_margin, _margin, 0, _margin);
  }

  @override
  double get gutter => 8;

  @override
  Widget frame(BuildContext context, Widget navigation) => frostHasTranslucentWindowBase(context)
      ? navigation
      : FrostSurface(role: FrostSurfaceRole.chrome, borderRadius: BorderRadius.circular(FrostRadius.lg), child: navigation);
}

final class FrostFlushSidebar extends FrostSidebarStyle {
  const FrostFlushSidebar({this.itemForm = FrostNavItemForm.tile});

  @override
  EdgeInsets margin(BuildContext context) => EdgeInsets.zero;

  @override
  double get gutter => 0;

  @override
  final FrostNavItemForm itemForm;

  @override
  bool get expandsOverContent => true;

  @override
  bool get floatingChrome => false;

  @override
  Widget frame(BuildContext context, Widget navigation) {
    // A solid panel: glass here would stack a second material against the
    // page's own pinned glass along the whole window height.
    if (frostHasTranslucentWindowBase(context)) return navigation;
    final tokens = FrostThemeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.isBlack ? tokens.canvas : tokens.surface,
        boxShadow: [...tokens.shadowAmbient, ...tokens.shadowContact],
        border: BorderDirectional(end: BorderSide(color: tokens.panelEdge)),
      ),
      child: Material(type: MaterialType.transparency, child: navigation),
    );
  }
}

final class FrostCustomSidebar extends FrostSidebarStyle {
  const FrostCustomSidebar({
    required this.outerMargin,
    required this.gutter,
    required this.frameBuilder,
    this.itemForm = FrostNavItemForm.tile,
    this.expandsOverContent = false,
  });

  final EdgeInsets outerMargin;
  final FrostSidebarFrameBuilder frameBuilder;

  @override
  final double gutter;

  @override
  final FrostNavItemForm itemForm;

  @override
  final bool expandsOverContent;

  @override
  bool get floatingChrome => false;

  @override
  EdgeInsets margin(BuildContext context) => outerMargin;

  @override
  Widget frame(BuildContext context, Widget navigation) => frameBuilder(context, navigation);
}

/// Navigation inset directly into the shell base, with no separate panel.
final class _FrostInsetSidebar extends FrostSidebarStyle {
  const _FrostInsetSidebar();
  @override
  EdgeInsets margin(BuildContext context) => EdgeInsets.zero;
  @override
  double get gutter => 0;
  @override
  FrostNavItemForm get itemForm => FrostNavItemForm.tile;
  @override
  bool get expandsOverContent => false;
  @override
  bool get floatingChrome => false;
  @override
  Widget frame(BuildContext context, Widget navigation) => navigation;
}
