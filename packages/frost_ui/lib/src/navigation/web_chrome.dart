import 'package:flutter/widgets.dart';

import '../controls/_dynamic_icon_button.dart';
import '../controls/_toolbar_geometry.dart';
import '../feedback/activity_indicator.dart';
import '../feedback/loading_gate.dart';
import '../feedback/progress.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/pinned_chrome.dart';
import '../overlays/menu_entry.dart';
import '../primitives/icon.dart';
import '../primitives/presence.dart';
import '../primitives/text.dart';
import '_page_header_leading.dart';
import 'page_header.dart';
import 'toolbar.dart';
import 'toolbar_menu_button.dart';

// The determinate line shares ProgressBar's four-point track.
const _webProgressHeight = 4.0;

/// A browser-free shell. Give it a finite height; [web] receives all remaining
/// space below the shared page header. The application owns URL navigation.
class FrostWebChrome extends StatefulWidget {
  const FrostWebChrome({
    required this.web,
    this.title,
    this.url,
    this.progress,
    this.loading = false,
    this.canGoBack = false,
    this.canGoForward = false,
    this.onBack,
    this.onForward,
    this.onReload,
    this.onStop,
    this.onOpenInBrowser,
    this.actions = const [],
    super.key,
  });
  final Widget web;
  final String? title;
  final Uri? url;
  final double? progress;
  final bool loading, canGoBack, canGoForward;

  /// Application actions appended to the same browser header. They share its
  /// responsive overflow and priority rules; no second toolbar is needed.
  final List<FrostToolbarItem> actions;
  final VoidCallback? onBack, onForward, onReload, onStop, onOpenInBrowser;
  @override
  State<FrostWebChrome> createState() => _WebChromeState();
}

class _WebChromeState extends State<FrostWebChrome> {
  late double? _lastProgress = widget.progress;
  @override
  void didUpdateWidget(FrostWebChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading) _lastProgress = widget.progress;
  }

  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context), icons = FrostIconSet.of(context), tokens = FrostThemeTokens.of(context);
    final close = Navigator.of(context).canPop()
        ? FrostToolbarControl(label: labels.close, icon: icons.close, showsLabel: false, onPressed: () => Navigator.of(context).maybePop())
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FrostLoadingGate(
          loading: widget.loading,
          builder: (context, shown) {
            final progress = widget.loading ? widget.progress : _lastProgress;
            final busy = widget.loading;
            final label = busy ? labels.stop : labels.reload, icon = busy ? icons.close : icons.refresh;
            final action = busy ? widget.onStop : widget.onReload;
            final header = FrostPageHeaderLeading(
              leading: close,
              child: FrostPageHeader(
                title: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.title case final title?) FrostText(title, role: FrostTextRole.headline, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (widget.url?.host case final host?)
                      if (host.isNotEmpty)
                        FrostText(host, role: FrostTextRole.footnote, tone: FrostTextTone.secondary, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
                actions: [
                  FrostToolbarItem.action(
                    icon: icons.back,
                    label: labels.back,
                    onPressed: widget.canGoBack ? widget.onBack : null,
                    priority: FrostToolbarPriority.high,
                  ),
                  FrostToolbarItem.action(icon: icons.forward, label: labels.forward, onPressed: widget.canGoForward ? widget.onForward : null),
                  FrostToolbarItem.custom(
                    minWidth: frostToolbarButtonGeometry(context).minimumWidth,
                    priority: FrostToolbarPriority.high,
                    overflowEntry: FrostMenuAction(label, icon: icon, onSelected: action),
                    builder: (context) => FrostDynamicIconButton(
                      label: label,
                      toolbar: true,
                      onPressed: action,
                      icon: shown && progress == null
                          ? Builder(
                              key: const ValueKey('web-wait'),
                              builder: (context) => FrostActivityForeground(
                                color: IconTheme.of(context).color ?? tokens.textSecondary,
                                child: const FrostActivityIndicator(size: FrostControlSize.compact, semanticLabel: null),
                              ),
                            )
                          : FrostIcon(icon, key: ValueKey(icon)),
                    ),
                  ),
                  if (widget.onOpenInBrowser != null)
                    FrostToolbarItem.action(
                      icon: icons.externalLink,
                      label: labels.openInBrowser,
                      onPressed: widget.onOpenInBrowser,
                      priority: FrostToolbarPriority.low,
                    ),
                  ...widget.actions,
                ],
              ),
            );
            return FrostPinnedChromeGlass(
              opacity: 1,
              child: Stack(
                children: [
                  header,
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: _webProgressHeight,
                    child: FrostPresence(
                      visible: shown && progress != null,
                      effect: FrostPresenceEffect.expand,
                      child: FrostProgressBar(value: (progress ?? 0).clamp(0.0, 1.0), semanticLabel: labels.loading),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Expanded(child: widget.web),
      ],
    );
  }
}
