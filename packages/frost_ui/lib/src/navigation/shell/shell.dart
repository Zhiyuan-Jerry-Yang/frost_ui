import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frost_window/frost_window.dart' show FrostCaptionMode;

import '../../controls/_button_control.dart';
import '../../controls/buttons.dart';
import '../../controls/picker_option.dart';
import '../../feedback/_skeleton_geometry.dart';
import '../../foundation/_control_geometry.dart';
import '../../foundation/density.dart';
import '../../foundation/icon_data.dart';
import '../../foundation/mask.dart';
import '../../foundation/metrics.dart';
import '../../foundation/radius.dart';
import '../../foundation/scope.dart';
import '../../foundation/spacing.dart';
import '../../foundation/tokens.dart';
import '../../foundation/typography.dart';
import '../../layout/auto_scaffold.dart';
import '../../layout/content_viewport.dart';
import '../../layout/window_caption_scope.dart';
import '../../motion/_selection_feedback.dart';
import '../../motion/layout_crossfade.dart';
import '../../overlays/_value_picker.dart';
import '../../overlays/tooltip.dart';
import '../../primitives/_page_outline.dart';
import '../../primitives/click_surface.dart';
import '../../primitives/divider.dart';
import '../../primitives/icon.dart' show FrostIcon;
import '../../primitives/surface.dart';
import '../../surface/_window_background.dart';
import '../_destination_status.dart';
import '../_navigation_tile.dart';
import '../_shell_back_scope.dart';
import '../shell_navigation_scope.dart';
import '../window_caption.dart';

part 'base_layer.dart';
part 'caption_row.dart';
part 'content_sheet.dart';
part 'destination.dart';
part 'mobile_bar.dart';
part 'sidebar.dart';

/// One navigation destination: an icon and its caller-owned label.
@immutable
class FrostNavDestination {
  const FrostNavDestination({required this.icon, required this.label, this.badge = 0, this.progress, this.builder})
    : assert(progress == null || (progress >= 0 && progress <= 1));

  final FrostIconData icon;
  final String label;

  /// Positive counts appear beside expanded labels or over collapsed icons.
  /// Zero (and negative counts) hide the count; the expanded ring is separate.
  final int badge;

  /// Determinate status, in 0–1. Only expanded sidebar rows show a ring.
  /// All forms include this value in their caller-localized announcement.
  final double? progress;

  /// Wraps the shared navigation target in every rendered navigation form.
  /// Use a stable wrapper to measure an animation destination or add local
  /// confirmation feedback. Preserve [child] so activation, status and semantics
  /// continue through the shared implementation. Hidden More-menu rows are not
  /// wrapped; a destination with no visible target has no measurement anchor.
  final Widget Function(BuildContext context, Widget child)? builder;
}

class _DestinationItem extends StatelessWidget {
  const _DestinationItem({required this.destination, required this.child});
  final FrostNavDestination destination;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final item = FrostDestinationStatus(badge: destination.badge, progress: destination.progress, child: child);
    return destination.builder?.call(context, item) ?? item;
  }
}

/// Geometry of the navigation, shared by every sidebar style.
@immutable
class FrostNavigationMetrics {
  const FrostNavigationMetrics({required this.railWidth, required this.expandedWidth, required this.expandableMinWidth, required this.mobileMaxWidth});

  static const standard = FrostNavigationMetrics(railWidth: 80, expandedWidth: 176, expandableMinWidth: 1200, mobileMaxWidth: 600);

  /// Collapsed sidebar width: icons with labels in tooltips.
  final double railWidth;

  /// Expanded sidebar width: icons with labels beside them.
  final double expandedWidth;

  /// The window width from which the sidebar may be expanded.
  final double expandableMinWidth;

  /// Below this window width the phone's bottom navigation replaces the sidebar.
  final double mobileMaxWidth;
}

/// Where the shell placed its sidebar, for overlays that line up with it
/// (such as a dock under the navigation).
@immutable
class FrostShellGeometry {
  const FrostShellGeometry({required this.sidebarRight, required this.iconAxis, required this.bottom});

  /// Actual right edge of the sidebar in window coordinates.
  final double sidebarRight;

  /// Horizontal centre of the sidebar's icon column, from the window's left.
  final double iconAxis;

  /// Distance from the content sheet's bottom to the window's bottom.
  final double bottom;
}

/// The app's navigation shell: a desktop sidebar (or a phone bottom bar)
/// around the current page. Routing stays in the app; the shell reports
/// selections and owns page-level Back and Escape. Desktop platforms keep one
/// Back control beside the brand in an available client title row. Native
/// window controls and hosts without a client title row use the sidebar header:
/// fixed Back on the navigation icon axis, with the brand revealed on expansion.
/// Compact layouts keep Back in the content page header.
class FrostShell extends StatefulWidget {
  const FrostShell({
    required this.destinations,
    required this.selectedIndex,
    required this.atDestinationRoot,
    required this.onDestinationSelected,
    required this.canGoBack,
    required this.onBack,
    required this.showsMobileNavigation,
    this.sidebarStyle = const FrostSidebarStyle.inset(),
    required this.child,
    this.secondaryDestinations = const [],
    this.selectedSecondaryIndex,
    this.onSecondarySelected,
    this.metrics = FrostNavigationMetrics.standard,
    this.initiallyExpanded = false,
    this.onExpandedChanged,
    this.desktopOverlayBuilder,
    this.brand,
    super.key,
  });

  final List<FrostNavDestination> destinations;

  /// The primary destination the current page belongs to, if any.
  final int? selectedIndex;

  /// Whether the current page is the selected destination's own root page,
  /// with nothing pushed above it. Selecting that destination again then
  /// signals [FrostShellNavigationScope.primaryReselection] (scroll to top,
  /// refresh) instead of navigating.
  final bool atDestinationRoot;
  final ValueChanged<int> onDestinationSelected;

  /// Destinations in the More menu (collapsed) or the secondary group
  /// (expanded). Not shown on the phone's bottom bar.
  final List<FrostNavDestination> secondaryDestinations;
  final int? selectedSecondaryIndex;
  final ValueChanged<int>? onSecondarySelected;

  /// Whether Back has somewhere to go: a pushed page or a parent location.
  final bool canGoBack;
  final VoidCallback onBack;

  /// Whether destination pages provide mobile navigation. Place one
  /// [FrostShellDestination] inside the content Navigator's retained root page.
  /// Secondary routes cover that page; [atDestinationRoot] does not hide the bar.
  final bool showsMobileNavigation;
  final FrostSidebarStyle sidebarStyle;
  final FrostNavigationMetrics metrics;

  /// The saved choice of an expanded sidebar where the window makes room for
  /// it. Read once; the shell then owns the choice and reports changes
  /// through [onExpandedChanged].
  final bool initiallyExpanded;

  /// Called when the user expands or collapses the sidebar beside the page.
  /// Collapsing forced by a narrow window, and opening over the page, are
  /// not choices and are not reported.
  final ValueChanged<bool>? onExpandedChanged;

  /// Desktop layers placed over the page, aligned with the sidebar.
  final Widget Function(BuildContext context, FrostShellGeometry geometry)? desktopOverlayBuilder;

  /// Optional app identity in the client title row, or beside Back in an
  /// expanded sidebar when the native host owns the title controls.
  /// Hosts without a window caption use the same sidebar placement.
  final Widget? brand;
  final Widget child;

  @override
  State<FrostShell> createState() => _FrostShellState();
}

class _FrostShellState extends State<FrostShell> with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey();
  final _pageKey = GlobalKey();
  late final AnimationController _sidebarProgress = AnimationController(vsync: this, value: widget.initiallyExpanded ? 1 : 0);
  final FocusNode _moreButtonFocus = FocusNode(debugLabel: 'More navigation');
  final ValueNotifier<({int index, int sequence})> _primaryReselection = ValueNotifier((index: 0, sequence: 0));

  /// The user's choice where the sidebar sits beside the page.
  late bool _expandedBeside = widget.initiallyExpanded;

  /// Whether the sidebar is open over the page in a narrow window.
  bool _expandedOver = false;

  /// Whether the window made room for an expanded sidebar at the last
  /// layout; null before the first one.
  bool? _besidePage;

  /// The progress to draw until a layout switch lands on the controller.
  double? _settledProgress;

  bool get _expandedTarget => (_besidePage ?? true) ? _expandedBeside : _expandedOver;

  void _toggleExpansion() {
    if (_besidePage ?? true) {
      _expandedBeside = !_expandedBeside;
      widget.onExpandedChanged?.call(_expandedBeside);
    } else {
      _expandedOver = !_expandedOver;
    }
    _springToTarget();
  }

  void _closeOverlay() {
    if (!_expandedOver) return;
    _expandedOver = false;
    _springToTarget();
  }

  void _springToTarget() {
    // One spring drives the width, the content start, the overlays and
    // every label, so they stay in step; a toggle mid-way turns back at the
    // current speed instead of restarting.
    FrostMotion.springTo(context, _sidebarProgress, _expandedTarget ? 1.0 : 0.0, FrostMotion.standard);
  }

  /// Follows the window across the width that makes room for the sidebar.
  /// The switch jumps rather than animates, so the sidebar tracks a resize.
  void _updateBesidePage(bool besidePage) {
    if (_besidePage == besidePage) return;
    final first = _besidePage == null;
    _besidePage = besidePage;
    _expandedOver = false;
    final target = _expandedTarget ? 1.0 : 0.0;
    if (first && _sidebarProgress.value == target) return;
    // Layout cannot drive the controller; draw the target now and move the
    // controller there after the frame.
    _settledProgress = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _settledProgress = null;
      _sidebarProgress.value = _expandedTarget ? 1.0 : 0.0;
    });
  }

  void _selectIndex(int index) {
    _closeOverlay();
    if (index == widget.selectedIndex && widget.atDestinationRoot) {
      _primaryReselection.value = (index: index, sequence: _primaryReselection.value.sequence + 1);
      return;
    }
    widget.onDestinationSelected(index);
  }

  void _selectSecondary(int index) {
    _closeOverlay();
    widget.onSecondarySelected?.call(index);
  }

  @override
  void dispose() {
    _sidebarProgress.dispose();
    _moreButtonFocus.dispose();
    _primaryReselection.dispose();
    super.dispose();
  }

  EdgeInsets _frame(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final margin = widget.sidebarStyle.margin(context);
    // System insets are often fractional; whole physical pixels keep the
    // page's pinned glass edges (and joins between them) crisp.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    double snap(double value) => (value * pixelRatio).roundToDouble() / pixelRatio;
    return EdgeInsets.fromLTRB(snap(safe.left + margin.left), snap(safe.top + margin.top), 0, snap(safe.bottom + margin.bottom));
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    final style = widget.sidebarStyle;
    return FrostAutoScaffold(
      mobileBreakpoint: metrics.mobileMaxWidth,
      builder: (context, layout, orientation, useHorizontalLayout) {
        final besidePage = useHorizontalLayout && layout.width >= metrics.expandableMinWidth;
        _updateBesidePage(besidePage);
        final canExpand = besidePage || (useHorizontalLayout && style.expandsOverContent);
        final showSidebar = useHorizontalLayout;
        final hasCaption = FrostWindowCaptionScope.windowOf(context) != null;
        final captionState = FrostWindowCaptionScope.stateOf(context);
        final nativeControls = captionState?.nativeControls ?? Rect.zero;
        final usesCaptionNavigation = hasCaption && captionState?.mode == FrostCaptionMode.client;
        // The native-controls strip contains no app navigation. Keep its normal
        // 28px height, but grow for actual AppKit geometry rather than clipping it.
        final captionHeight = captionState?.mode == FrostCaptionMode.nativeControls
            ? math.max(_nativeCaptionHeight, nativeControls.isEmpty ? 0.0 : nativeControls.bottom + FrostGap.inline)
            : _shellCaptionHeight;
        return _FrostDestinationNavigation(
          enabled: !useHorizontalLayout && widget.showsMobileNavigation,
          navigation: _MobileNavBar(destinations: widget.destinations, selectedIndex: widget.selectedIndex ?? 0, onDestinationSelected: _selectIndex),
          child: FrostShellBackHost(
            canGoBack: widget.canGoBack,
            onBack: widget.onBack,
            builder: (context, canGoBack, goBack) => FrostShellNavigationScope(
              ownsBackControl: useHorizontalLayout,
              canGoBack: canGoBack,
              goBack: goBack,
              primaryReselection: _primaryReselection,
              floatingChrome: style.floatingChrome,
              // Menus, dialogs, panels and viewers handle Escape inside their own
              // subtree first; only an unhandled Escape bubbles up to this
              // page-level shortcut, so each press closes one layer. It has its
              // own intent: the Scaffolds between here and the page map
              // DismissIntent to their drawers and would swallow it.
              child: Shortcuts(
                shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _PageBackIntent()},
                child: Actions(
                  actions: {
                    _PageBackIntent: _PageBackAction(overlayOpen: () => _expandedOver, closeOverlay: _closeOverlay, canGoBack: () => canGoBack, goBack: goBack),
                  },
                  child: FrostLayoutCrossfade(
                    layoutIdentity: useHorizontalLayout,
                    child: _ShellBase(
                      enabled: useHorizontalLayout,
                      child: Scaffold(
                        key: _scaffoldKey,
                        backgroundColor: useHorizontalLayout ? Colors.transparent : FrostThemeTokens.of(context).surface,
                        // The shell never shrinks for the keyboard: the sidebar, its
                        // overlays stay put. Destination pages own mobile navigation; pages
                        // keep avoiding it through their own Scaffolds.
                        resizeToAvoidBottomInset: false,
                        extendBody: false,
                        body: AnimatedBuilder(
                          animation: _sidebarProgress,
                          builder: (context, _) {
                            final progress = canExpand ? (_settledProgress ?? _sidebarProgress.value) : 0.0;
                            final railWidth = lerpDouble(metrics.railWidth, metrics.expandedWidth, progress)!;
                            // Open over the page, the sidebar leaves the page where
                            // the collapsed rail put it.
                            final pageRail = besidePage ? railWidth : metrics.railWidth;
                            final overPage = !besidePage && progress > 0;
                            final frame = _frame(context);
                            final overlay = widget.desktopOverlayBuilder;
                            // Native window controls stay above application
                            // navigation; the sidebar header shares its icon axis.
                            final sidebarTop =
                                (hasCaption ? captionHeight : 0.0) + math.max(frame.top, !hasCaption && style is _FrostInsetSidebar ? FrostGap.related : 0.0);
                            // Only positioned layers: the Stack must take the body size.
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // Pages start beside the sidebar so it never covers
                                // their hit targets. The tree keeps one shape so a
                                // fold or resize that switches layouts keeps state.
                                Positioned.fill(
                                  left: showSidebar ? frame.left + pageRail + style.gutter : 0,
                                  top: hasCaption
                                      ? captionHeight
                                      : showSidebar
                                      ? sidebarTop
                                      : 0,
                                  right: 0,
                                  bottom: showSidebar ? FrostGap.related : 0,
                                  child: MediaQuery.removePadding(
                                    context: context,
                                    removeLeft: showSidebar,
                                    removeTop: showSidebar,
                                    child: FrostCaptionClearance(
                                      child: _ContentSheet(
                                        enabled: showSidebar,
                                        radius: FrostRadius.borderRadius(FrostRadius.lg),
                                        child: FrostContentViewport(
                                          key: _pageKey,
                                          navigationReserve: besidePage ? metrics.expandedWidth - railWidth : 0,
                                          child: widget.child,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // A click outside the open panel closes it.
                                if (overPage)
                                  Positioned.fill(
                                    child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeOverlay),
                                  ),
                                if (showSidebar)
                                  Positioned(
                                    left: frame.left,
                                    top: sidebarTop,
                                    bottom: frame.bottom,
                                    width: railWidth,
                                    child: DecoratedBox(
                                      // A light shadow sets the open panel apart from
                                      // the page it covers.
                                      decoration: BoxDecoration(
                                        boxShadow: overPage
                                            ? [
                                                ...FrostThemeTokens.of(context).shadowAmbient,
                                                ...FrostThemeTokens.of(context).shadowContact,
                                              ].map((s) => s.copyWith(color: s.color.withValues(alpha: s.color.a * progress.clamp(0.0, 1.0)))).toList()
                                            : null,
                                      ),
                                      child: style.frame(
                                        context,
                                        _SidebarNavigation(
                                          destinations: widget.destinations,
                                          selectedIndex: widget.selectedIndex,
                                          secondaryDestinations: widget.secondaryDestinations,
                                          selectedSecondaryIndex: widget.selectedSecondaryIndex,
                                          metrics: metrics,
                                          itemForm: style.itemForm,
                                          progress: progress,
                                          header: usesCaptionNavigation
                                              ? null
                                              : _SidebarHeader(metrics: metrics, progress: progress, brand: widget.brand, onBack: canGoBack ? goBack : null),
                                          controls: _SidebarToggle(expanded: _expandedTarget, onToggle: canExpand ? _toggleExpansion : null),
                                          onDestinationSelected: _selectIndex,
                                          onSecondarySelected: _selectSecondary,
                                          moreButtonFocus: _moreButtonFocus,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (hasCaption)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: 0,
                                    height: captionHeight,
                                    child: _CaptionRow(
                                      iconAxis: frame.left + metrics.railWidth / 2,
                                      nativeCaption: hasCaption,
                                      showsBack: usesCaptionNavigation && useHorizontalLayout,
                                      onBack: canGoBack ? goBack : null,
                                      brand: usesCaptionNavigation ? widget.brand : null,
                                    ),
                                  ),
                                if (useHorizontalLayout && overlay != null)
                                  overlay(
                                    context,
                                    FrostShellGeometry(
                                      sidebarRight: showSidebar ? frame.left + railWidth : 0,
                                      iconAxis: frame.left + _SidebarNavigation.iconAxis(metrics, progress),
                                      bottom: FrostGap.related,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Page-level Escape: close a sidebar open over the page, then leave a
/// focused text field, then go back one page. Top-level pages have nowhere
/// to go, so the key is left unhandled there.
class _PageBackIntent extends Intent {
  const _PageBackIntent();
}

class _PageBackAction extends Action<_PageBackIntent> {
  _PageBackAction({required this.overlayOpen, required this.closeOverlay, required this.canGoBack, required this.goBack});

  final bool Function() overlayOpen;
  final VoidCallback closeOverlay;
  final bool Function() canGoBack;
  final VoidCallback goBack;

  bool get _editing => FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null;

  @override
  bool isEnabled(_PageBackIntent intent) => overlayOpen() || _editing || canGoBack();

  @override
  Object? invoke(_PageBackIntent intent) {
    if (overlayOpen()) {
      closeOverlay();
    } else if (_editing) {
      FocusManager.instance.primaryFocus?.unfocus();
    } else {
      goBack();
    }
    return null;
  }
}
