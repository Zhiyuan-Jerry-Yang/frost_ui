import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../display/code_block.dart';
import '../display/disclosure.dart';
import '../foundation/icon_data.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../layout/auto_scaffold.dart';
import '../navigation/page_header.dart';
import '../primitives/surface.dart';
import '_skeleton_geometry.dart';
import 'empty_state.dart';
import 'error_action_button.dart';

// Keep technical details bounded inside a page or a short inline message.
const _errorDetailsMaximumHeight = 220.0;

/// A full page for a failed load, with page-owned navigation and retry.
class FrostErrorPage extends StatelessWidget {
  const FrostErrorPage({required String this.message, required this.onRetry, this.fullUrl, this.details, super.key}) : error = null;
  const FrostErrorPage.fromError({required Object this.error, required this.onRetry, super.key}) : message = null, fullUrl = null, details = null;
  final String? message;
  final Object? error;
  final VoidCallback onRetry;
  final String? fullUrl, details;
  @override
  Widget build(BuildContext context) => FrostAutoScaffold(
    builder: (context, layout, orientation, horizontal) => Scaffold(
      // An opaque route cannot reveal the previous route's canvas. Inherit a
      // shell surface when present, and supply the canvas for standalone pages.
      backgroundColor: FrostSurfaceScope.maybeOf(context)?.background ?? FrostThemeTokens.of(context).canvas,
      body: SafeArea(
        child: Column(
          children: [
            if (!horizontal)
              FrostPageHeader(
                title: FrostSkeletonText(child: Text(FrostScope.labelsOf(context).error)),
                onBack: () => Navigator.of(context).maybePop(),
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(FrostGap.of(context).section),
                child: switch (error) {
                  final error? => FrostErrorContent.fromError(error: error, onRetry: onRetry),
                  null => FrostErrorContent(message: message!, onRetry: onRetry, fullUrl: fullUrl, details: details),
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Error presentation shares the empty state's readable, scrollable structure.
class FrostErrorContent extends StatelessWidget {
  const FrostErrorContent({required String this.message, required this.onRetry, this.retryLabel, this.fullUrl, this.details, super.key}) : error = null;
  const FrostErrorContent.fromError({required Object this.error, required this.onRetry, this.retryLabel, super.key})
    : message = null,
      fullUrl = null,
      details = null;
  final String? message;
  final Object? error;
  final VoidCallback? onRetry;
  final String? retryLabel, fullUrl, details;
  @override
  Widget build(BuildContext context) {
    final presenter = FrostScope.errorsOf(context), labels = FrostScope.labelsOf(context);
    final message = error == null ? this.message! : presenter.message(context, error!);
    final details = error == null ? this.details : presenter.details(error!);
    final hasDetails = details != null && details.trim().isNotEmpty;
    final defaultTitle = FrostErrorTitleScope.maybeOf(context) ?? labels.error;
    final customIcon = error == null ? null : presenter.icon?.call(context, error!);
    return Semantics(
      liveRegion: true,
      child: FrostEmptyIconInk(
        color: customIcon == null ? FrostThemeTokens.of(context).negativeInk : FrostThemeTokens.of(context).textTertiary,
        child: FrostStateContent(
          icon: customIcon ?? FrostIconSet.of(context).error,
          title: error == null ? defaultTitle : presenter.title?.call(context, error!) ?? defaultTitle,
          message: message,
          actions: Wrap(
            alignment: WrapAlignment.center,
            spacing: FrostGap.related,
            runSpacing: FrostGap.related,
            children: [
              if (error != null && presenter.action?.call(context, error!) != null) FrostErrorActionButton(error: error!, onResolved: onRetry),
              FrostButton(label: retryLabel ?? labels.retry, onPressed: onRetry),
            ],
          ),
          details: fullUrl == null && !hasDetails
              ? null
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (fullUrl case final url?) FrostCodeBlock(text: url, wrap: FrostCodeWrap.anywhere),
                    if (fullUrl != null && hasDetails) const SizedBox(height: FrostGap.group),
                    if (hasDetails) FrostErrorDetails(details: details),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Collapsed technical details retain their expansion state and use the code
/// block's copy feedback and announcement. Public arguments are unchanged.
class FrostErrorDetails extends StatelessWidget {
  const FrostErrorDetails({required this.details, this.initiallyExpanded = false, super.key});
  final String details;
  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) => FrostDisclosure(
    title: FrostScope.labelsOf(context).errorDetails,
    initiallyExpanded: initiallyExpanded,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _errorDetailsMaximumHeight),
      child: SingleChildScrollView(
        primary: false,
        child: FrostCodeBlock(text: details, wrap: FrostCodeWrap.anywhere),
      ),
    ),
  );
}

// A loading context supplies a more specific default without changing generic
// error pages or asking Apps to recognize and restyle paged errors themselves.
class FrostErrorTitleScope extends InheritedWidget {
  const FrostErrorTitleScope({required this.title, required super.child, super.key});
  final String title;
  static String? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostErrorTitleScope>()?.title;
  @override
  bool updateShouldNotify(FrostErrorTitleScope oldWidget) => title != oldWidget.title;
}
