import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controls/buttons.dart';
import '../display/section_header.dart';
import '../foundation/_layout_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../layout/_content_padding.dart';
import '../layout/content_viewport.dart';
import '../motion/_material_reveal.dart';
import '../motion/spring.dart';
import '../overlays/panel_action.dart';
import '../overlays/sheet.dart';
import '../primitives/_page_outline.dart';
import '../primitives/divider.dart';

// Main content keeps the same minimum room as a split-view pane.
const _minimumContentWidth = 240.0;

/// A trailing inspector that becomes a medium/large sheet below 900 local pixels.
///
/// The owner controls [open]. User dismissal calls [onOpenChanged] once;
/// external closure or a size-class transfer does not. Inspector State may
/// rebuild when moving between the sheet and the inline form. Keep shared
/// editing state in the caller when it must survive that transfer.
enum FrostInspectorPresentation { inline, sheet }

class _InspectorPresentation extends InheritedWidget {
  const _InspectorPresentation({required this.presentation, required super.child});
  final FrostInspectorPresentation presentation;
  @override
  bool updateShouldNotify(_InspectorPresentation oldWidget) => presentation != oldWidget.presentation;
}

class FrostInspector extends StatefulWidget {
  static FrostInspectorPresentation presentationOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InspectorPresentation>()?.presentation ?? FrostInspectorPresentation.inline;

  const FrostInspector({
    required this.child,
    required this.inspector,
    required this.open,
    required this.onOpenChanged,
    this.title,
    this.width = 320,
    this.sheetBelow = FrostSizeClass.expanded,
    this.sheetDetents = const [FrostSheetDetent.medium, FrostSheetDetent.large],
    this.showsSheetCloseButton = true,
    super.key,
  }) : assert(width > 0 && width < double.infinity);
  final Widget child;
  final Widget inspector;
  final bool open;
  final ValueChanged<bool> onOpenChanged;
  final String? title;
  final double width;

  /// Size classes below this threshold present the inspector as a sheet.
  /// The default includes compact and medium local space. An explicit threshold
  /// preserves callers needing another policy without changing navigation.
  final FrostSizeClass sheetBelow;

  /// Forwarded to the compact sheet. Fitted must be the only detent; natural
  /// content is capped at the available height, while lazy viewports use large.
  final List<FrostSheetDetent> sheetDetents;

  /// Hides only the sheet's close control. With a null [title], the drag handle
  /// precedes the inspector directly. Barrier dismiss semantics, Escape and
  /// system back remain available; inline headers keep their close control.
  final bool showsSheetCloseButton;

  @override
  State<FrostInspector> createState() => _FrostInspectorState();
}

class _InspectorSheet {
  final body = GlobalKey<_InspectorSheetBodyState>();
  ModalRoute<void>? route;
  bool programmatic = false;
}

class _FrostInspectorState extends State<FrostInspector> {
  _InspectorSheet? _sheet;
  bool _compact = false;
  bool _syncScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(FrostInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (mounted) _syncSheet();
    });
  }

  void _closeSheet(_InspectorSheet sheet) {
    sheet.programmatic = true;
    final route = sheet.route;
    final navigator = route?.navigator;
    if (route == null || navigator == null || !route.isActive) return;
    // Never pop a newer dialog above this owned sheet.
    if (route.isCurrent) {
      navigator.pop();
    } else {
      navigator.removeRoute(route);
    }
  }

  void _syncSheet() {
    final wantsSheet = _compact && widget.open;
    final sheet = _sheet;
    if (!wantsSheet) {
      if (sheet != null) _closeSheet(sheet);
      return;
    }
    if (sheet != null) {
      if (!sheet.programmatic) sheet.body.currentState?.update(widget.inspector);
      return;
    }
    final session = _InspectorSheet();
    _sheet = session;
    showFrostSheet<void>(
      context: context,
      title: null,
      scrollable: false,
      detents: widget.sheetDetents,
      showsCloseButton: widget.showsSheetCloseButton,
      builder: (context) {
        session.route = ModalRoute.of<void>(context);
        if (!mounted || session.programmatic || !_compact || !widget.open) {
          session.programmatic = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _closeSheet(session));
          return const SizedBox.shrink();
        }
        return _InspectorPresentation(
          presentation: FrostInspectorPresentation.sheet,
          child: _InspectorSheetBody(key: session.body, child: widget.inspector),
        );
      },
    ).whenComplete(() {
      if (!mounted || _sheet != session) return;
      _sheet = null;
      if (!session.programmatic && _compact && widget.open) {
        widget.onOpenChanged(false);
      } else {
        // A transfer may have been reversed while the old route was closing.
        _scheduleSync();
      }
    });
  }

  @override
  void dispose() {
    final sheet = _sheet;
    if (sheet != null) {
      sheet.programmatic = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _closeSheet(sheet));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final threshold = widget.sheetBelow.minimumWidth;
      if (_compact != (constraints.maxWidth < threshold)) {
        _compact = constraints.maxWidth < threshold;
        _scheduleSync();
      }
      return _buildContent(context);
    },
  );

  Widget _buildContent(BuildContext context) {
    if (_compact) return widget.child;
    final panel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.title != null) ...[
          FrostContentColumn(
            child: FrostSectionHeader(
              title: widget.title!,
              trailing: [
                FrostButton.icon(
                  icon: FrostIconSet.of(context).close,
                  label: FrostScope.labelsOf(context).close,
                  style: FrostIconButtonStyle.plain,
                  size: FrostControlSize.compact,
                  onPressed: () => widget.onOpenChanged(false),
                ),
              ],
            ),
          ),
          const SizedBox(height: FrostGap.related),
        ],
        Expanded(
          child: FrostPanelActionScope(
            origin: context,
            close: () async {
              if (!mounted || !widget.open) return false;
              widget.onOpenChanged(false);
              return true;
            },
            child: _InspectorPresentation(presentation: FrostInspectorPresentation.inline, child: widget.inspector),
          ),
        ),
      ],
    );
    final reduced = MediaQuery.disableAnimationsOf(context);
    final line = 1 / MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final channel = FrostPageOutline.channelOf(context);
        final inspectorChannel = Directionality.of(context) == TextDirection.ltr ? channel : 0.0;
        final mainChannel = channel - inspectorChannel;
        final full = math.min(widget.width + inspectorChannel, math.max(0.0, constraints.maxWidth - mainChannel - _minimumContentWidth - line));
        return FrostSpringBuilder(
          value: widget.open ? full : 0,
          spring: FrostMotion.standard,
          child: FrostPageOutline(
            radius: FrostPageOutline.of(context),
            channelClaimed: true,
            scrollbarChannel: inspectorChannel,
            child: FrostContentPadding(
              padding: EdgeInsets.symmetric(horizontal: FrostGap.of(context).rowInset),
              child: panel,
            ),
          ),
          builder: (context, value, child) {
            final width = value.clamp(0.0, full);
            final reserved = width > 0 ? width + line : 0.0;
            // Reduced motion changes layout immediately. An outgoing panel can
            // fade over that new layout for the shared short fade duration.
            final paintWidth = reduced ? full + line : reserved;
            return Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: FrostPageOutline(radius: FrostPageOutline.of(context), channelClaimed: true, scrollbarChannel: mainChannel, child: widget.child),
                    ),
                    SizedBox(width: reserved),
                  ],
                ),
                if (full > 0 || !reduced)
                  PositionedDirectional(
                    end: 0,
                    top: 0,
                    bottom: 0,
                    width: paintWidth,
                    child: IgnorePointer(
                      ignoring: !widget.open,
                      child: ExcludeFocus(
                        excluding: !widget.open,
                        child: ExcludeSemantics(
                          excluding: !widget.open,
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: AlignmentDirectional.centerStart,
                              minWidth: (full > 0 ? full : widget.width) + line,
                              maxWidth: (full > 0 ? full : widget.width) + line,
                              child: FrostAnimatedMaterialReveal(
                                opacity: widget.open ? 1 : 0,
                                duration: reduced ? FrostMotion.reducedFade : FrostMotion.hover,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const FrostDivider(axis: Axis.vertical),
                                    Expanded(child: child!),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _InspectorSheetBody extends StatefulWidget {
  const _InspectorSheetBody({required this.child, super.key});
  final Widget child;
  @override
  State<_InspectorSheetBody> createState() => _InspectorSheetBodyState();
}

class _InspectorSheetBodyState extends State<_InspectorSheetBody> {
  late Widget _child = widget.child;
  void update(Widget child) {
    if (_child != child) setState(() => _child = child);
  }

  @override
  Widget build(BuildContext context) => _child;
}
