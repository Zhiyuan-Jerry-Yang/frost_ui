import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/page_transition.dart';
import '_control_geometry.dart';
import '_menu_metrics.dart';
import '_row_metrics.dart';
import '_tab_metrics.dart';
import 'density.dart';
import 'feedback.dart';
import 'fonts.dart';
import 'metrics.dart';
import 'radius.dart';
import 'scope.dart';
import 'sizes.dart';
import 'spacing.dart';
import 'tokens.dart';
import 'typography.dart';

// Keep idle/hover/drag thumbs inside the outside page margin.
const _scrollbarThickness = 6.0;

/// Builds the app's [ThemeData] from its [FrostConfig]. Material component
/// themes are restyled into the Frost language, so the Material widgets Frost
/// components use internally look like the rest.
abstract final class FrostTheme {
  static ThemeData build({
    required FrostConfig config,
    required Brightness brightness,
    required TargetPlatform platform,
    required Locale locale,
    FrostTone tone = FrostTone.neutral,
    Color? accent,
    FrostDensity density = FrostDensity.comfortable,
    bool reducedMotion = false,
  }) {
    final palettes = config.palettes;
    return _build(
      config: config,
      palettes: palettes,
      tokens: palettes.palette(brightness, tone, accent ?? palettes.defaultAccent(brightness)),
      brightness: brightness,
      fonts: config.fonts.resolve(platform: platform, locale: locale),
      platform: platform,
      density: density.forPlatform(platform),
      reducedMotion: reducedMotion,
    );
  }

  static ThemeData _build({
    required FrostConfig config,
    required FrostPalettes palettes,
    required FrostThemeTokens tokens,
    required Brightness brightness,
    required FrostFontChain fonts,
    required TargetPlatform platform,
    required FrostDensity density,
    required bool reducedMotion,
  }) {
    // Controls shrink with the density; their vertical padding gives up the
    // difference so labels stay centred at every size.
    final shrink = density.name == FrostDensity.compact.name ? FrostGap.inline : 0.0;
    final groupGap = FrostGap.group - shrink;
    final rowInset = FrostGap.rowInset - shrink;
    final colorScheme = _colorScheme(palettes: palettes, tokens: tokens, brightness: brightness);
    final typography = FrostTypography(
      platform: platform,
      base: TextStyle(fontFamily: fonts.family, fontFamilyFallback: fonts.fallbacks),
      monospace: config.fonts.monospace,
    );
    final controlRadius = FrostRadius.forHeight(density.controlHeight);
    final menuSize = FrostMenuMetrics.sizeFor(density);
    final menuGeometry = frostControlTextGeometry(baseHeight: density.heightFor(menuSize), style: typography.style(FrostTextRole.callout));
    final menuRadius = FrostRadius.inner(FrostRadius.lg, FrostMenuMetrics.panelInset);
    final rowGeometry = frostControlTextGeometry(baseHeight: density.heightFor(FrostControlSize.regular), style: typography.style(FrostTextRole.body));
    final base = _applyTextTheme(
      ThemeData(
        platform: platform,
        colorScheme: colorScheme,
        // Pages are transparent over the window's ambient backdrop.
        scaffoldBackgroundColor: Colors.transparent,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {for (final platform in TargetPlatform.values) platform: FrostPageTransitionsBuilder(reducedMotion: reducedMotion)},
        ),
        fontFamily: fonts.family,
        fontFamilyFallback: fonts.fallbacks,
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        extensions: [tokens, density, typography, FrostConfigTheme(config)],
        iconTheme: IconThemeData(size: FrostControlSize.regular.iconSize, color: tokens.textSecondary),
      ),
      typography,
    );

    return base.copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: tokens.fillStrong,
      hoverColor: tokens.fillSubtle,
      focusColor: tokens.fillSubtle,
      dividerColor: tokens.separator,
      scrollbarTheme: const ScrollbarThemeData(thickness: WidgetStatePropertyAll(_scrollbarThickness), crossAxisMargin: 0),
      // Material's zero-width border is a physical hairline at every DPR.
      // Its compatibility layout slot stays one logical pixel until migration.
      dividerTheme: DividerThemeData(color: tokens.separator, thickness: 0, space: 1),
      appBarTheme: AppBarThemeData(
        // Headers sit on the ambient backdrop like the title bar above them.
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        // A transparent bar cannot infer icon brightness; use the palette's.
        systemOverlayStyle: frostSystemOverlayStyle(tokens),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: tokens.fillSubtle,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: _shape(config, controlRadius),
      ),
      tabBarTheme: TabBarThemeData(
        overlayColor: WidgetStateProperty.resolveWith((states) => frostShowsFocus(states) ? tokens.fillSubtle : frostFeedbackSurface(tokens, states)),
        labelColor: tokens.textPrimary,
        unselectedLabelColor: tokens.textSecondary,
        indicatorColor: tokens.keyGraphicOn(tokens.surface),
        // A short rounded bar under the label, in the readable accent tone.
        indicator: FrostTabIndicator(color: tokens.keyGraphicOn(tokens.surface)),
        indicatorSize: TabBarIndicatorSize.label,
        // Hover and press read as a rounded pill, like the navigation items,
        // rather than a square block that runs into the bar's corners.
        splashBorderRadius: FrostRadius.borderRadius(FrostRadius.sm),
        dividerColor: tokens.separator,

        labelPadding: const EdgeInsets.symmetric(horizontal: frostTabInset),
        labelStyle: typography.style(FrostTextRole.callout),
        unselectedLabelStyle: typography.style(FrostTextRole.callout),
        splashFactory: NoSplash.splashFactory,
      ),
      checkboxTheme: CheckboxThemeData(
        mouseCursor: frostClickCursor,
        overlayColor: WidgetStateProperty.resolveWith((states) => frostFeedbackSurface(tokens, states)),
        side: WidgetStateBorderSide.resolveWith(
          (states) => frostFeedbackBorder(
            tokens,
            states,
            restingSide: BorderSide(
              color: states.contains(WidgetState.selected) ? tokens.keyGraphicOn(tokens.surface) : colorScheme.onSurfaceVariant,
              width: 2,
            ),
          ),
        ),
        shape: _shape(config, FrostRadius.xs),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.keyGraphicOn(tokens.surface).withValues(alpha: states.contains(WidgetState.disabled) ? .38 : 1)
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(tokens.keyGraphicOn(tokens.surface) == tokens.accent ? tokens.onAccent : tokens.surface),
      ),
      radioTheme: RadioThemeData(
        mouseCursor: frostClickCursor,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => frostFeedbackSurface(tokens, states, resting: frostShowsFocus(states) ? tokens.fillSubtle : Colors.transparent),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colorScheme.outline
              : states.contains(WidgetState.selected)
              ? tokens.selectionInk
              : colorScheme.onSurfaceVariant,
        ),
      ),
      sliderTheme: SliderThemeData(
        mouseCursor: frostClickCursor,
        activeTrackColor: tokens.keyGraphicOn(tokens.surface),
        thumbColor: tokens.keyGraphicOn(tokens.surface),
        inactiveTrackColor: tokens.line,
        overlayColor: tokens.fillSubtle,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: tokens.keyGraphicOn(tokens.surface), linearTrackColor: tokens.line),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: tokens.surfaceRaised,
          shape: _shape(config, FrostRadius.sm),
          shadows: [...tokens.shadowAmbient, ...tokens.shadowContact],
        ),
        textStyle: base.textTheme.bodySmall?.copyWith(color: tokens.textPrimary),
        padding: EdgeInsets.symmetric(horizontal: groupGap, vertical: FrostGap.related),
        waitDuration: const Duration(milliseconds: 500),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: frostFeedbackStyle(tokens).copyWith(
          minimumSize: WidgetStatePropertyAll(Size(0, menuGeometry.height)),
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: FrostMenuMetrics.rowInset, vertical: menuGeometry.verticalInset)),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: WidgetStatePropertyAll(typography.style(FrostTextRole.callout)),
          shape: WidgetStatePropertyAll(_shape(config, menuRadius)),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          minimumSize: const WidgetStatePropertyAll(Size(FrostMenuMetrics.minimumWidth, 0)),
          maximumSize: const WidgetStatePropertyAll(Size(FrostMenuMetrics.maximumWidth, double.infinity)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(FrostMenuMetrics.panelInset)),
          backgroundColor: WidgetStatePropertyAll(tokens.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(_shape(config, FrostRadius.lg, side: BorderSide(color: tokens.edgeHairline))),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(
              overlayColor: Colors.transparent,
              minimumSize: Size.square(density.controlHeight),
              iconSize: FrostControlSize.regular.iconSize,
              foregroundColor: colorScheme.onSurfaceVariant,
              disabledForegroundColor: tokens.textQuaternary,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              shape: _shape(config, FrostRadius.forHeight(density.controlHeight)),
            ).copyWith(
              mouseCursor: frostClickCursor,
              backgroundBuilder: frostButtonFeedbackBackground,
              backgroundColor: WidgetStateProperty.resolveWith((states) => frostButtonRestingSurface(tokens, states, resting: Colors.transparent)),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: frostFeedbackStyle(tokens, restingSide: BorderSide.none).side,
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              overlayColor: Colors.transparent,
              foregroundColor: colorScheme.onSurface,
              disabledForegroundColor: tokens.textQuaternary,
              textStyle: base.textTheme.labelLarge,
              shape: _shape(config, controlRadius),
            ).copyWith(
              mouseCursor: frostClickCursor,
              backgroundBuilder: frostButtonFeedbackBackground,
              backgroundColor: WidgetStateProperty.resolveWith((states) => frostButtonRestingSurface(tokens, states, resting: Colors.transparent)),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: frostFeedbackStyle(tokens, restingSide: BorderSide.none).side,
            ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: tokens.actionFill,
              overlayColor: Colors.transparent,
              foregroundColor: tokens.onAction,
              disabledBackgroundColor: tokens.fill,
              disabledForegroundColor: tokens.disabledText,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: rowInset, vertical: groupGap),
              textStyle: base.textTheme.labelLarge,
              shape: _shape(config, controlRadius),
            ).copyWith(
              mouseCursor: frostClickCursor,
              backgroundBuilder: frostPrimaryButtonFeedbackBackground,
              backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? tokens.fill : tokens.actionFill),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: frostFeedbackStyle(tokens).side,
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              overlayColor: Colors.transparent,
              backgroundColor: tokens.surfaceRaised,
              foregroundColor: colorScheme.onSurface,
              disabledBackgroundColor: tokens.fillSubtle,
              disabledForegroundColor: tokens.textQuaternary,
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.symmetric(horizontal: rowInset, vertical: groupGap),
              textStyle: base.textTheme.labelLarge,
              shape: _shape(config, controlRadius),
            ).copyWith(
              mouseCursor: frostClickCursor,
              backgroundBuilder: frostSecondaryButtonFeedbackBackground,
              backgroundColor: WidgetStatePropertyAll(tokens.fill),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: frostFeedbackStyle(tokens).side,
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              overlayColor: Colors.transparent,
              foregroundColor: colorScheme.onSurface,
              disabledForegroundColor: tokens.textQuaternary,
              padding: EdgeInsets.symmetric(horizontal: rowInset, vertical: groupGap),
              textStyle: base.textTheme.labelLarge,
              shape: _shape(config, controlRadius),
            ).copyWith(
              mouseCursor: frostClickCursor,
              backgroundBuilder: frostSecondaryButtonFeedbackBackground,
              backgroundColor: WidgetStatePropertyAll(tokens.fill),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: frostFeedbackStyle(tokens).side,
            ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(style: _segmentedButtonStyle(config, tokens, colorScheme, base.textTheme.labelLarge, density)),
      chipTheme: ChipThemeData(
        // Selected chips use the accent wash, a check and accent ink; resting
        // chips stay neutral and never carry a coloured outline.
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Color.alphaBlend(frostButtonStateLayer(tokens, states, FrostFeedbackRole.quiet), tokens.selectionSurface)
              : frostFeedbackSurface(tokens, states, resting: states.contains(WidgetState.disabled) ? tokens.fillSubtle : tokens.fill),
        ),
        backgroundColor: tokens.fill,
        selectedColor: tokens.selectionSurface,
        disabledColor: tokens.fillSubtle,
        checkmarkColor: tokens.selectionInk,
        labelStyle: base.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(color: tokens.selectionInk),
        side: WidgetStateBorderSide.resolveWith((states) => frostFeedbackBorder(tokens, states)),
        shape: _shape(config, controlRadius),
        padding: const EdgeInsets.symmetric(horizontal: FrostGap.related, vertical: FrostGap.inline),
        showCheckmark: true,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: tokens.fill,
        contentPadding: EdgeInsets.symmetric(horizontal: groupGap, vertical: groupGap),
        border: _inputBorder(Colors.transparent, controlRadius, width: 0),
        enabledBorder: _inputBorder(Colors.transparent, controlRadius, width: 0),
        focusedBorder: _inputBorder(tokens.fieldFocus, controlRadius, width: FrostMetrics.fieldFocusWidth),
        errorBorder: _inputBorder(tokens.negativeInk, controlRadius, width: FrostMetrics.fieldFocusWidth),
        focusedErrorBorder: _inputBorder(tokens.negativeInk, controlRadius, width: FrostMetrics.fieldFocusWidth),
        hintStyle: WidgetStateTextStyle.resolveWith(
          (states) => base.textTheme.bodyMedium!.copyWith(color: states.contains(WidgetState.disabled) ? tokens.textQuaternary : tokens.textTertiary),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        menuPadding: EdgeInsets.zero,
        color: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: _shape(config, controlRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: _shape(config, FrostRadius.xxl),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: _shape(config, FrostRadius.xxl, corners: const BorderRadius.vertical(top: Radius.circular(FrostRadius.xxl))),
      ),
      listTileTheme: ListTileThemeData(
        mouseCursor: frostClickCursor,
        iconColor: tokens.textSecondary,
        textColor: tokens.textPrimary,
        titleTextStyle: typography.style(FrostTextRole.body).copyWith(color: tokens.textPrimary),
        subtitleTextStyle: typography.style(FrostTextRole.footnote).copyWith(color: tokens.textSecondary),
        leadingAndTrailingTextStyle: typography.style(FrostTextRole.body).copyWith(color: tokens.textSecondary),
        shape: _shape(config, FrostRadius.sm),
        minTileHeight: density.heightFor(FrostControlSize.regular),
        minVerticalPadding: rowGeometry.verticalInset,
        minLeadingWidth: frostRowIconColumn,
        horizontalTitleGap: FrostGap.related,
        visualDensity: VisualDensity.standard,
        contentPadding: EdgeInsets.symmetric(horizontal: rowInset),
      ),
    );
  }

  static ThemeData _applyTextTheme(ThemeData theme, FrostTypography typography) => theme.copyWith(
    textTheme: TextTheme(
      displayLarge: typography.style(FrostTextRole.hero),
      displayMedium: typography.style(FrostTextRole.hero),
      displaySmall: typography.style(FrostTextRole.value),
      headlineLarge: typography.style(FrostTextRole.value),
      headlineMedium: typography.style(FrostTextRole.title1),
      headlineSmall: typography.style(FrostTextRole.title1),
      titleLarge: typography.style(FrostTextRole.title2),
      titleMedium: typography.style(FrostTextRole.headline),
      titleSmall: typography.style(FrostTextRole.headline),
      bodyLarge: typography.style(FrostTextRole.body),
      bodyMedium: typography.style(FrostTextRole.body),
      bodySmall: typography.style(FrostTextRole.subheadline),
      labelLarge: typography.style(FrostTextRole.callout),
      labelMedium: typography.style(FrostTextRole.footnote),
      labelSmall: typography.style(FrostTextRole.caption),
    ).apply(bodyColor: theme.colorScheme.onSurface, displayColor: theme.colorScheme.onSurface),
  );

  static ColorScheme _colorScheme({required FrostPalettes palettes, required FrostThemeTokens tokens, required Brightness brightness}) {
    final base = ColorScheme.fromSeed(seedColor: tokens.accent, brightness: brightness);
    return base.copyWith(
      primary: tokens.accent,
      onPrimary: tokens.onAccent,
      primaryContainer: tokens.selectionSurface,
      onPrimaryContainer: tokens.selectionInk,
      secondary: tokens.accent,
      onSecondary: tokens.onAccent,
      secondaryContainer: tokens.selectionSurface,
      onSecondaryContainer: tokens.selectionInk,
      tertiary: tokens.accent,
      onTertiary: tokens.onAccent,
      tertiaryContainer: tokens.selectionSurface,
      onTertiaryContainer: tokens.selectionInk,
      error: tokens.negativeInk,
      onError: tokens.surface,
      errorContainer: tokens.negativeTint,
      onErrorContainer: tokens.negativeInk,
      surface: tokens.surface,
      surfaceTint: tokens.surfaceTint,
      onSurface: tokens.textPrimary,
      surfaceContainerLowest: tokens.canvas,
      surfaceContainerLow: tokens.surface,
      surfaceContainer: tokens.surfaceInset,
      surfaceContainerHigh: tokens.surfaceRaised,
      surfaceContainerHighest: tokens.surfaceMuted,
      onSurfaceVariant: tokens.textSecondary,
      inverseSurface: tokens.isDark ? palettes.lightNeutral.surface : palettes.darkNeutral.surface,
      onInverseSurface: tokens.isDark ? palettes.lightNeutral.textPrimary : palettes.darkNeutral.textPrimary,
      outline: tokens.line,
      outlineVariant: tokens.line,
      shadow: tokens.shadow,
      scrim: tokens.onMediaScrim,
    );
  }

  static OutlinedBorder _shape(FrostConfig config, double radius, {BorderRadiusGeometry? corners, BorderSide side = BorderSide.none}) =>
      config.continuousCorners
      ? RoundedSuperellipseBorder(borderRadius: corners ?? FrostRadius.borderRadius(radius), side: side)
      : RoundedRectangleBorder(borderRadius: corners ?? FrostRadius.borderRadius(radius), side: side);

  static ButtonStyle _segmentedButtonStyle(FrostConfig config, FrostThemeTokens tokens, ColorScheme colorScheme, TextStyle? labelStyle, FrostDensity density) {
    final groupGap = FrostGap.group - (density.name == FrostDensity.compact.name ? FrostGap.inline : 0.0);
    final controlRadius = FrostRadius.forHeight(density.controlHeight);
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, density.controlHeight)),
      textStyle: WidgetStatePropertyAll(labelStyle),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: groupGap, vertical: FrostGap.related)),
      shape: WidgetStatePropertyAll(_shape(config, controlRadius)),
      side: WidgetStateProperty.resolveWith((states) {
        return frostFeedbackBorder(tokens, states);
      }),
      mouseCursor: frostClickCursor,
      backgroundBuilder: frostButtonFeedbackBackground,
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.isDark ? tokens.fillSubtle : tokens.surfaceRaised;
        }

        return tokens.isDark ? tokens.surfaceRaised : tokens.fill;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return tokens.textQuaternary;
        }
        if (states.contains(WidgetState.selected)) {
          return tokens.selectionInk;
        }

        return colorScheme.onSurfaceVariant;
      }),
      iconColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) && !states.contains(WidgetState.disabled)
            ? tokens.keyGraphicOn(tokens.surfaceRaised)
            : colorScheme.onSurfaceVariant,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, double controlRadius, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: FrostRadius.borderRadius(controlRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Status and navigation bar styling over the transparent ambient backdrop.
SystemUiOverlayStyle frostSystemOverlayStyle(FrostThemeTokens tokens) => (tokens.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
);
