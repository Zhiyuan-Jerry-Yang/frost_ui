import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';

import '../controls/_button_control.dart';
import '../controls/_button_types.dart';
import '../controls/picker.dart';
import '../controls/picker_option.dart';
import '../feedback/progress.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../motion/_spring_simulation.dart';
import '../overlays/_popover_options.dart';
import '../overlays/popover.dart';
import '../overlays/sheet.dart';
import '../primitives/text.dart';
import '_reader_anchor.dart';
import '_reader_style.dart';
import 'content_viewport.dart';
import 'pinned_chrome.dart';

export '_reader_style.dart' show FrostReaderSettings;

// The reading measure excludes the shared outer page insets.
const _readingMeasure = 680.0;

/// A lazy, vertically scrolling reading page. The application owns settings
/// and persistence. [header] receives a ready-made compact settings button;
/// place it among the header's own actions, rather than adding a second bar.
///
/// Body-role FrostText and FrostRichText inherit the reading size and leading.
/// During settings changes retain stable keys and the same content order.
/// The viewport preserves the top text position within the same layout pass;
/// non-text items preserve the proportional offset within their new height.
/// Asynchronous insertion/removal is a separate application scroll policy.
/// At the physical start/end, the scroll bounds take precedence.
class FrostReaderLayout extends StatefulWidget {
  const FrostReaderLayout({required this.header, required this.slivers, required this.settings, required this.onSettingsChanged, this.controller, super.key});
  final Widget Function(BuildContext context, Widget settingsButton) header;
  final List<Widget> slivers;
  final FrostReaderSettings settings;
  final ValueChanged<FrostReaderSettings> onSettingsChanged;
  final ScrollController? controller;
  static FrostReaderSettings of(BuildContext context) {
    final settings = FrostReaderStyle.maybeOf(context);
    if (settings == null) throw FlutterError('FrostReaderLayout.of requires a FrostReaderLayout ancestor.');
    return settings;
  }

  @override
  State<FrostReaderLayout> createState() => _ReaderState();
}

class _ReaderState extends State<FrostReaderLayout> with SingleTickerProviderStateMixin {
  final _viewport = GlobalKey();
  final _owned = ScrollController();
  final _focus = FocusNode();
  late final _pageMotion = AnimationController.unbounded(vsync: this)..addListener(_pageTick);
  ScrollController get _scroll => widget.controller ?? _owned;

  @override
  void didUpdateWidget(FrostReaderLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _pageMotion.stop();
      final render = _viewport.currentContext?.findRenderObject();
      if (render is FrostReaderViewport) render.preserveReadingPosition(_viewport.currentContext!);
    }
    if (oldWidget.controller != widget.controller) _pageMotion.stop();
  }

  void _pageTick() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _scroll.jumpTo(_pageMotion.value.clamp(position.minScrollExtent, position.maxScrollExtent));
  }

  KeyEventResult _key(BuildContext context, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final backwards = event.logicalKey == LogicalKeyboardKey.pageUp;
    if (!backwards && event.logicalKey != LogicalKeyboardKey.pageDown && event.logicalKey != LogicalKeyboardKey.space) return KeyEventResult.ignored;
    if (!_scroll.hasClients) return KeyEventResult.ignored;
    final body = FrostReaderStyle.apply(context, FrostTextRole.body, FrostTypography.of(context).style(FrostTextRole.body));
    final line = MediaQuery.textScalerOf(context).scale(body.fontSize!) * body.height!;
    final position = _scroll.position;
    final top = (_viewport.currentContext?.findRenderObject() as FrostReaderViewport?)?.contentTop ?? 0;
    final distance = math.max(0.0, position.viewportDimension - top - line);
    final target = (position.pixels + (backwards ? -distance : distance)).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageMotion.stop();
      _scroll.jumpTo(target);
    } else {
      final velocity = _pageMotion.isAnimating ? _pageMotion.velocity : 0.0;
      _pageMotion.stop();
      _pageMotion.value = position.pixels;
      unawaited(_pageMotion.animateWith(frostSpringSimulation(FrostMotion.standard, position.pixels, target, velocity)));
    }
    return KeyEventResult.handled;
  }

  Widget _settingsButton(BuildContext context) => FrostPopoverDetents(
    detents: const [FrostSheetDetent.fitted],
    child: FrostPopover(
      title: FrostScope.labelsOf(context).readerSettings,
      builder: (context, node, open) => FrostButtonControl(
        label: FrostScope.labelsOf(context).readerSettings,
        icon: FrostIconSet.of(context).textFormat,
        iconStyle: FrostIconButtonStyle.plain,
        size: FrostControlSize.compact,
        focusNode: node,
        onPressed: open,
      ),
      contentBuilder: (context, close) => _ReaderOptions(settings: widget.settings, onChanged: widget.onSettingsChanged),
    ),
  );
  double get _progress {
    if (!_scroll.hasClients || !_scroll.position.hasContentDimensions) return 0;
    final position = _scroll.position;
    final range = position.maxScrollExtent - position.minScrollExtent;
    return range <= 0 ? 1 : ((position.pixels - position.minScrollExtent) / range).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _pageMotion.dispose();
    _focus.dispose();
    _owned.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostReaderStyle(
    settings: widget.settings,
    child: Builder(
      builder: (context) => Focus(
        focusNode: _focus,
        onKeyEvent: (node, event) => _key(context, node, event),
        child: FrostPinnedChrome(
          chrome: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostContentColumn(child: widget.header(context, _settingsButton(context))),
              AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) => FrostProgressBar(value: _progress, semanticLabel: FrostScope.labelsOf(context).readingProgress),
              ),
            ],
          ),
          body: Listener(
            onPointerDown: (_) {
              _pageMotion.stop();
              _focus.requestFocus();
            },
            child: NotificationListener<UserScrollNotification>(
              onNotification: (notification) {
                if (notification.direction != ScrollDirection.idle) _pageMotion.stop();
                return false;
              },
              child: FrostReaderScrollView(
                viewportKey: _viewport,
                controller: _scroll,
                slivers: [
                  const FrostChromeSpacer(),
                  for (final sliver in widget.slivers)
                    SliverLayoutBuilder(
                      builder: (context, constraints) =>
                          FrostSliverContentColumn(maxWidth: _readingMeasure + FrostMetrics.browseInset(constraints.crossAxisExtent) * 2, sliver: sliver),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ReaderOptions extends StatefulWidget {
  const _ReaderOptions({required this.settings, required this.onChanged});
  final FrostReaderSettings settings;
  final ValueChanged<FrostReaderSettings> onChanged;
  @override
  State<_ReaderOptions> createState() => _ReaderOptionsState();
}

class _ReaderOptionsState extends State<_ReaderOptions> {
  late FrostReaderSettings _settings = widget.settings;
  void _change(FrostReaderSettings settings) {
    setState(() => _settings = settings);
    widget.onChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context);
    final base = FrostTypography.of(context).style(FrostTextRole.body).fontSize!;
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FrostText(labels.textSize, role: FrostTextRole.headline),
          const SizedBox(height: FrostGap.related),
          FrostPicker<int>.segmented(
            options: [
              for (var step = -2; step <= 2; step++) FrostPickerOption(value: step, label: (base + frostReaderTextOffsets[step + 2]).toStringAsFixed(0)),
            ],
            value: _settings.textSizeStep,
            onChanged: (value) => _change(_settings.copyWith(textSizeStep: value)),
            label: labels.textSize,
          ),
          const SizedBox(height: FrostGap.group),
          FrostText(labels.lineSpacing, role: FrostTextRole.headline),
          const SizedBox(height: FrostGap.related),
          FrostPicker<int>.segmented(
            options: [for (final (step, height) in frostReaderLineHeights.indexed) FrostPickerOption(value: step, label: height.toString())],
            value: _settings.lineSpacingStep,
            onChanged: (value) => _change(_settings.copyWith(lineSpacingStep: value)),
            label: labels.lineSpacing,
          ),
        ],
      ),
    );
  }
}
