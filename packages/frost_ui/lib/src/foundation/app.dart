import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../controls/toast.dart';
import '../feedback/scroll_to_top.dart';
import '../feedback/skeleton.dart';
import '../layout/auto_scaffold.dart';
import '../media/system_chrome.dart';
import '../surface/_window_background.dart';
import 'appearance.dart';
import 'density.dart';
import 'input_feedback.dart';
import 'metrics.dart';
import 'scope.dart';
import 'theme.dart';
import 'tokens.dart';

/// Theme and environment integration; routing remains owned by the caller.
class FrostApp extends StatelessWidget {
  const FrostApp.router({
    required this.config,
    required this.routerConfig,
    required this.title,
    this.appearance,
    this.density = FrostDensity.comfortable,
    this.locale,
    this.supportedLocales = const [Locale('en', 'US')],
    this.localizationsDelegates,
    this.builder,
    this.debugShowCheckedModeBanner = false,
    super.key,
  });
  final FrostConfig config;
  final RouterConfig<Object> routerConfig;
  final String title;
  final FrostAppearance? appearance;
  final FrostDensity density;
  final Locale? locale;
  final Iterable<Locale> supportedLocales;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final TransitionBuilder? builder;
  final bool debugShowCheckedModeBanner;

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final inheritedMedia = MediaQuery.maybeOf(context);
    final reduced = inheritedMedia?.disableAnimations ?? view.platformDispatcher.accessibilityFeatures.disableAnimations;
    final effectiveLocale = locale ?? view.platformDispatcher.locale;
    final selected = appearance ?? FrostAppearance.initial(config.palettes);
    final transparency = FrostScope.maybeOf(context)?.reduceTransparency ?? false;
    ThemeData theme(Brightness brightness) => FrostTheme.build(
      config: config,
      brightness: brightness,
      platform: defaultTargetPlatform,
      locale: effectiveLocale,
      tone: selected.effectiveToneFor(brightness),
      darkModeColor: selected.darkModeColor,
      accent: selected.accentFor(brightness),
      density: density,
      reducedMotion: reduced,
    );
    return FrostScope(
      config: config,
      reduceTransparency: transparency,
      child: MaterialApp.router(
        title: title,
        routerConfig: routerConfig,
        debugShowCheckedModeBanner: debugShowCheckedModeBanner,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        themeMode: selected.mode,
        themeAnimationDuration: reduced ? Duration.zero : FrostMotion.layoutFade,
        themeAnimationCurve: Curves.easeInOutCubic,
        locale: locale,
        supportedLocales: supportedLocales,
        localizationsDelegates: localizationsDelegates,
        builder: (context, child) {
          final data = MediaQuery.of(context);
          final targetBrightness = switch (selected.mode) {
            ThemeMode.light => Brightness.light,
            ThemeMode.dark => Brightness.dark,
            ThemeMode.system => data.platformBrightness,
          };
          return MediaQuery(
            data: data.copyWith(disableAnimations: reduced, textScaler: inheritedMedia?.textScaler ?? data.textScaler),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: frostSystemOverlayStyle(FrostThemeTokens.of(context)),
              child: SkeletonizerConfig(
                data: frostSkeletonConfig(context),
                child: FrostLayoutScope(
                  child: FrostToastHost(
                    child: FrostInputFeedback(
                      child: FrostAmbientThemeScope(
                        tokens: config.palettes.palette(
                          targetBrightness,
                          selected.effectiveToneFor(targetBrightness),
                          selected.accentFor(targetBrightness),
                          darkModeColor: selected.darkModeColor,
                        ),
                        child: FrostMediaSystemChromeHost(
                          child: FrostScrollToTopHost(child: Builder(builder: (context) => builder?.call(context, child) ?? child ?? const SizedBox.shrink())),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
