import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../foundation/control_scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../primitives/text.dart';
import '_popover_options.dart';
import '_popover_surface.dart';
import 'adaptive_panel.dart';
import 'menu_anchor.dart';
import 'sheet.dart';

// Popover sizing is independent of menu item geometry.
const _minimumWidth = 160.0;
const _maximumWidth = 400.0;

class FrostPopover extends StatefulWidget {
  const FrostPopover({required this.builder, required this.contentBuilder, this.maxWidth, this.title, super.key})
    : assert(maxWidth == null || (maxWidth >= _minimumWidth && maxWidth < double.infinity));
  final FrostMenuTriggerBuilder builder;
  final Widget Function(BuildContext context, VoidCallback close) contentBuilder;

  /// Optional ceiling; defaults to 400 and always yields to the viewport.
  /// Explicit values above 400 are for content needing a wide layout, such as
  /// a two-month calendar. Content still shrinks intrinsically, with a 160 floor.
  final double? maxWidth;
  final String? title;

  @override
  State<FrostPopover> createState() => _FrostPopoverState();
}

class _FrostPopoverState extends State<FrostPopover> {
  final _compactFocus = FocusNode();
  bool _sheetOpen = false;

  Future<void> _openSheet() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    _compactFocus.requestFocus();
    try {
      await showFrostSheet<void>(
        context: context,
        title: widget.title,
        detents: FrostPopoverDetents.of(context) ?? const [FrostSheetDetent.medium, FrostSheetDetent.large],
        builder: (context) {
          final route = ModalRoute.of(context)!;
          return widget.contentBuilder(context, () {
            if (context.mounted && route.isCurrent) Navigator.of(context).pop();
          });
        },
      );
    } finally {
      _sheetOpen = false;
      if (mounted) _compactFocus.requestFocus();
    }
  }

  @override
  void dispose() {
    _compactFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => frostPanelUsesSheet(context)
      ? widget.builder(context, _compactFocus, _openSheet)
      : FrostMenuHost(
          entries: const [],
          builder: widget.builder,
          panelBuilder: (context, close) => FrostControlScope(
            size: FrostControlSize.regular,
            toolbar: false,
            enabled: true,
            child: _PopoverPanel(maxWidth: widget.maxWidth, title: widget.title, child: widget.contentBuilder(context, close)),
          ),
        );
}

class _PopoverPanel extends StatelessWidget {
  const _PopoverPanel({required this.maxWidth, required this.title, required this.child});
  final double? maxWidth;
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final maximum = math.min(maxWidth ?? _maximumWidth, constraints.maxWidth);
      final minimum = math.min(_minimumWidth, maximum);
      return ConstrainedBox(
        constraints: BoxConstraints(minWidth: minimum, maxWidth: maximum),
        child: IntrinsicWidth(
          child: FrostPopoverSurface(
            child: SingleChildScrollView(
              primary: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (title != null) ...[FrostText(title!, role: FrostTextRole.headline), const SizedBox(height: FrostGap.related)],
                  child,
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
