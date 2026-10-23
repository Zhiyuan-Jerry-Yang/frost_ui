import 'package:flutter/material.dart';

import 'fonts.dart';
import 'icon_data.dart';
import 'skeleton_style.dart';
import 'tokens.dart';

/// Every text a Frost component may show on its own, in the current locale.
/// The library contains no language; the app supplies all of it.
@immutable
class FrostLabels {
  const FrostLabels({
    required this.retry,
    required this.retryAfter,
    required this.error,
    required this.errorDetails,
    required this.copyDetails,
    required this.copied,
    required this.loading,
    required this.actionSucceeded,
    required this.actionFailed,
    required this.loadFailed,
    required this.noMoreItems,
    required this.noItems,
    required this.pullToRefresh,
    required this.releaseToRefresh,
    required this.refreshing,
    required this.refreshComplete,
    required this.refreshFailed,
    required this.previous,
    required this.next,
    required this.back,
    required this.more,
    required this.expandNavigation,
    required this.collapseNavigation,
    required this.navigationStatus,
    required this.clearText,
    required this.search,
    required this.noResults,
    required this.clearSearch,
    required this.dismiss,
    required this.expandText,
    required this.collapseText,
    required this.showAll,
    required this.copy,
    required this.clearAll,
    required this.showPassword,
    required this.hidePassword,
    required this.chooseDate,
    required this.chooseTime,
    required this.increment,
    required this.decrement,
    required this.reorderHandle,
    required this.sortAscending,
    required this.sortDescending,
    required this.play,
    required this.pause,
    required this.loop,
    required this.mute,
    required this.unmute,
    required this.fullscreen,
    required this.exitFullscreen,
    required this.reload,
    required this.openInBrowser,
    required this.minimize,
    required this.maximize,
    required this.restore,
    required this.close,
    required this.cancel,
    required this.apply,
    required this.clear,
    required this.choose,
    required this.showInFolder,
    required this.selectedCount,
    required this.pageOf,
    required this.selectAll,
    required this.done,
    required this.itemPosition,
    required this.tableDimensions,
    required this.taskQueued,
    required this.taskRunning,
    required this.taskPaused,
    required this.taskCompleted,
    required this.taskFailed,
    required this.taskCancelled,
    required this.remove,
    required this.forward,
    required this.stop,
    required this.seek,
    required this.send,
    required this.attach,
    required this.readerSettings,
    required this.textSize,
    required this.lineSpacing,
    required this.readingProgress,
    required this.showReplies,
    required this.characterCount,
    required this.moreMedia,
  });

  final String retry;

  /// A disabled retry action while a rate limit counts down, in whole seconds.
  final String Function(int seconds) retryAfter;

  /// Title of a full-page error on compact layouts.
  final String error;
  final String errorDetails;
  final String copyDetails;

  /// Toast after the error details were copied.
  final String copied;
  final String loading;
  final String actionSucceeded, actionFailed;
  final String loadFailed;

  /// End of a nonempty paged list.
  final String noMoreItems;

  /// Generic empty-result title when a paged sliver has no App-owned content.
  final String noItems;
  final String pullToRefresh;
  final String releaseToRefresh;
  final String refreshing;
  final String refreshComplete;
  final String refreshFailed;

  /// Scroll a horizontal shelf back or forward.
  final String previous;
  final String next;
  final String back;

  /// The navigation overflow menu.
  final String more;
  final String expandNavigation;
  final String collapseNavigation;

  /// Destination count and progress for a single navigation announcement.
  /// A zero count is omitted; null progress means there is no progress value.
  /// Progress is a rounded percentage in 0–100, independent of visual form.
  final String Function(int count, int? progressPercent) navigationStatus;

  /// Clears a search or text field.
  final String clearText;

  /// Submits a search field.
  final String search;

  /// Search-empty title, formatted by the app with the current query.
  final String Function(String query) noResults;

  /// Clears a query from a search-empty state.
  final String clearSearch;

  /// Closes a toast or panel.
  final String dismiss;
  final String expandText;
  final String collapseText;
  final String showAll;
  final String copy;
  final String clearAll;
  final String showPassword;
  final String hidePassword;
  final String chooseDate;
  final String chooseTime;
  final String increment;
  final String decrement;
  final String reorderHandle;
  final String sortAscending;
  final String sortDescending;
  final String play;
  final String pause;
  final String loop;
  final String mute;
  final String unmute;
  final String fullscreen;
  final String exitFullscreen;
  final String reload;
  final String openInBrowser;
  final String minimize;
  final String maximize;
  final String restore;
  final String close;
  final String cancel;

  /// Date-range application and draft clearing.
  final String apply, clear;

  /// Path selection and platform reveal actions, supplied by the app.
  final String choose, showInFolder;
  final String Function(int count) selectedCount;
  final String Function(int page, int total) pageOf;

  /// Bulk selection and reorder announcements, localized by the application.
  final String selectAll, done;
  final String taskQueued, taskRunning, taskPaused, taskCompleted, taskFailed, taskCancelled;

  /// Search removal, browser navigation and playback position.
  final String remove, forward, stop, seek;

  /// Social composition and reading settings, localized by the application.
  final String send, attach, readerSettings, textSize, lineSpacing, readingProgress;
  final String Function(int count) showReplies, moreMedia;
  final String Function(int count, int limit) characterCount;
  final String Function(int position, int total) itemPosition;

  /// Full data dimensions; rows excludes the header, including unbuilt rows.
  final String Function(int rows, int columns) tableDimensions;
}

/// Turns failures into user-facing text. [message] is the localized summary;
/// [details] is optional technical detail shown collapsed (status, endpoint),
/// which must never contain credentials or private content.
@immutable
class FrostErrorPresenter {
  const FrostErrorPresenter({required this.message, required this.details, this.title, this.icon, this.action});

  final String Function(BuildContext context, Object error) message;
  final String? Function(Object error) details;

  /// Optional localized title and semantic icon; null retains the default error.
  final String? Function(BuildContext context, Object error)? title;
  final FrostIconData? Function(BuildContext context, Object error)? icon;

  /// Resolves a recoverable failure. Mapping must be side-effect free; work
  /// starts only when the user activates the returned action.
  final FrostErrorAction? Function(BuildContext context, Object error)? action;
}

/// App-owned recovery work. True resolves the failure; false leaves it in place.
/// Error controls retry once after true, while their original owner is mounted.
@immutable
class FrostErrorAction {
  const FrostErrorAction({required this.label, required this.icon, required this.onPressed});
  final String label;
  final FrostIconData icon;
  final Future<bool> Function() onPressed;
}

/// What an app chooses about the shared design language. The design values
/// themselves ([FrostMetrics], [FrostMotion], surface materials) are fixed.
///
/// Keep one instance per app (a top-level `final`); [FrostScope] compares
/// configurations by identity of their parts.
@immutable
class FrostConfig {
  const FrostConfig({
    required this.palettes,
    required this.fonts,
    required this.icons,
    required this.labels,
    required this.errors,
    this.continuousCorners = true,
    this.predictiveBack = true,
    this.skeleton,
  });

  /// Palettes, default accent and accent presets; start from
  /// [FrostPalettes.pink] and `copyWith` a different accent.
  final bool continuousCorners;

  /// Previews an internal return by shrinking the page at its fixed centre.
  /// False keeps the page still during the system gesture, then uses the normal
  /// pop transition. This does not control Android's app-to-home animation.
  final bool predictiveBack;
  final FrostSkeletonStyle? skeleton;
  final FrostPalettes palettes;
  final FrostFonts fonts;
  final FrostIconSet icons;

  /// Labels in the locale of [context]; called during build.
  final FrostLabels Function(BuildContext context) labels;
  final FrostErrorPresenter errors;

  FrostConfig copyWith({
    FrostPalettes? palettes,
    FrostFonts? fonts,
    FrostIconSet? icons,
    FrostLabels Function(BuildContext context)? labels,
    FrostErrorPresenter? errors,
    bool? continuousCorners,
    bool? predictiveBack,
    FrostSkeletonStyle? skeleton,
  }) => FrostConfig(
    palettes: palettes ?? this.palettes,
    fonts: fonts ?? this.fonts,
    icons: icons ?? this.icons,
    labels: labels ?? this.labels,
    errors: errors ?? this.errors,
    continuousCorners: continuousCorners ?? this.continuousCorners,
    predictiveBack: predictiveBack ?? this.predictiveBack,
    skeleton: skeleton ?? this.skeleton,
  );
}

/// Carries the [FrostConfig] inside a theme built by `FrostTheme.build`, so
/// every widget under that theme can reach it without a [FrostScope].
@immutable
class FrostConfigTheme extends ThemeExtension<FrostConfigTheme> {
  const FrostConfigTheme(this.config);

  final FrostConfig config;

  @override
  FrostConfigTheme copyWith({FrostConfig? config}) => FrostConfigTheme(config ?? this.config);

  @override
  FrostConfigTheme lerp(ThemeExtension<FrostConfigTheme>? other, double t) => t < .5 || other is! FrostConfigTheme ? this : other;
}

/// Provides the user's material preferences, and optionally a [FrostConfig]
/// that overrides the theme's, to every Frost widget below it. Place it
/// above the app's `WidgetsApp`.
class FrostScope extends InheritedWidget {
  const FrostScope({required super.child, this.config, this.reduceTransparency = false, super.key});

  /// Overrides the configuration carried by the theme, if given.
  final FrostConfig? config;

  /// Draws glass surfaces as opaque panels. High contrast does the same
  /// regardless of this flag.
  final bool reduceTransparency;

  static FrostScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostScope>();

  /// The configuration of the nearest scope, else of the nearest Frost theme.
  static FrostConfig configOf(BuildContext context) {
    final config = maybeOf(context)?.config ?? Theme.of(context).extension<FrostConfigTheme>()?.config;
    assert(config != null, 'No FrostConfig: build the theme with FrostTheme.build or place a FrostScope above this widget.');
    return config!;
  }

  /// Whether glass surfaces render opaque here.
  static bool solidSurfaces(BuildContext context) => (maybeOf(context)?.reduceTransparency ?? false) || MediaQuery.highContrastOf(context);

  /// Labels in the locale of [context].
  static FrostLabels labelsOf(BuildContext context) => configOf(context).labels(context);

  /// The app's error text.
  static FrostErrorPresenter errorsOf(BuildContext context) => configOf(context).errors;

  @override
  bool updateShouldNotify(FrostScope oldWidget) => !identical(config, oldWidget.config) || reduceTransparency != oldWidget.reduceTransparency;
}
