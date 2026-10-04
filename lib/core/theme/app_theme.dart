import 'package:flutter/material.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';

/// Material 3 themes built from the design tokens. Both register [AppColors]
/// so `context.colors` works everywhere. Components follow the Stitch design
/// system: flat surfaces, 1px borders, no in-canvas shadows, radii by role.
abstract final class AppTheme {
  static const fontFamily = 'Almarai';

  static final ThemeData dark = _build(Brightness.dark, AppColors.dark);
  static final ThemeData light = _build(Brightness.light, AppColors.light);

  static ThemeData _build(Brightness brightness, AppColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: ColorsManager.primary,
      onPrimary: ColorsManager.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.textPrimary,
      secondary: ColorsManager.accent,
      onSecondary: ColorsManager.darkBackground,
      // M3 paints selections (segmented buttons, chips, indicators) with the
      // secondary container; the design selects with the brand violet.
      secondaryContainer: c.primaryContainer,
      onSecondaryContainer: c.textPrimary,
      tertiary: ColorsManager.success,
      onTertiary: ColorsManager.darkBackground,
      error: ColorsManager.error,
      onError: ColorsManager.white,
      surface: c.surface,
      onSurface: c.textPrimary,
      onSurfaceVariant: c.textSecondary,
      surfaceContainerLowest: c.background,
      surfaceContainerLow: c.surface,
      surfaceContainer: c.surface,
      surfaceContainerHigh: c.surfaceRaised,
      surfaceContainerHighest: c.surfaceRaised,
      outline: c.border,
      outlineVariant: c.border,
      scrim: ColorsManager.scrim,
    );

    final roundedChip = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Dimens.radiusChip),
    );
    final roundedButton = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Dimens.radiusButton),
    );
    final borderSide = BorderSide(color: c.border, width: Dimens.borderWidth);
    const minButtonSize = Size(Dimens.touchTarget, Dimens.touchTarget);

    final textTheme =
        const TextTheme(
          displaySmall: Styles.font32Bold,
          headlineMedium: Styles.font24Bold,
          headlineSmall: Styles.font20Bold,
          titleLarge: Styles.font20Bold,
          titleMedium: Styles.font16Bold,
          titleSmall: Styles.font14Bold,
          bodyLarge: Styles.font16Regular,
          bodyMedium: Styles.font14Regular,
          bodySmall: Styles.font12Regular,
          labelLarge: Styles.font14Bold,
          labelMedium: Styles.font12Bold,
          labelSmall: Styles.font12Regular,
        ).apply(
          fontFamily: fontFamily,
          bodyColor: c.textPrimary,
          displayColor: c.textPrimary,
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: textTheme,
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      dividerTheme: DividerThemeData(
        color: c.border,
        thickness: Dimens.borderWidth,
        space: Dimens.borderWidth,
      ),
      extensions: [c],
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusCard),
          side: borderSide,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: Styles.font14Regular.copyWith(color: c.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Dimens.space16,
          vertical: Dimens.space12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusChip),
          borderSide: borderSide,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusChip),
          borderSide: borderSide,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusChip),
          borderSide: const BorderSide(
            color: ColorsManager.primary,
            width: Dimens.borderWidth,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusChip),
          borderSide: const BorderSide(
            color: ColorsManager.error,
            width: Dimens.borderWidth,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ColorsManager.primary,
          foregroundColor: ColorsManager.onPrimary,
          minimumSize: minButtonSize,
          shape: roundedButton,
          textStyle: Styles.font14Bold.copyWith(fontFamily: fontFamily),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: c.surfaceRaised,
          foregroundColor: c.textPrimary,
          side: borderSide,
          minimumSize: minButtonSize,
          shape: roundedButton,
          textStyle: Styles.font14Bold.copyWith(fontFamily: fontFamily),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ColorsManager.primary,
          minimumSize: minButtonSize,
          shape: roundedButton,
          textStyle: Styles.font14Bold.copyWith(fontFamily: fontFamily),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: c.textSecondary,
          minimumSize: minButtonSize,
          shape: roundedChip,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: ColorsManager.transparent,
        indicatorColor: c.primaryContainer,
        height: Dimens.bottomNavHeight,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => Styles.font12Bold.copyWith(
            fontFamily: fontFamily,
            color: states.contains(WidgetState.selected)
                ? ColorsManager.primary
                : c.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? ColorsManager.primary
                : c.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: c.surface,
        indicatorColor: c.primaryContainer,
        selectedIconTheme: const IconThemeData(color: ColorsManager.primary),
        unselectedIconTheme: IconThemeData(color: c.textSecondary),
        selectedLabelTextStyle: Styles.font12Bold.copyWith(
          fontFamily: fontFamily,
          color: ColorsManager.primary,
        ),
        unselectedLabelTextStyle: Styles.font12Regular.copyWith(
          fontFamily: fontFamily,
          color: c.textSecondary,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: ColorsManager.transparent,
        barrierColor: ColorsManager.scrim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusSheet),
          side: borderSide,
        ),
        titleTextStyle: Styles.font20Bold.copyWith(
          fontFamily: fontFamily,
          color: c.textPrimary,
        ),
        contentTextStyle: Styles.font14Regular.copyWith(
          fontFamily: fontFamily,
          color: c.textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surfaceRaised,
        surfaceTintColor: ColorsManager.transparent,
        modalBarrierColor: ColorsManager.scrim,
        showDragHandle: true,
        dragHandleColor: c.textMuted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.vertical(
            top: Radius.circular(Dimens.radiusSheet),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceRaised,
        contentTextStyle: Styles.font14Regular.copyWith(
          fontFamily: fontFamily,
          color: c.textPrimary,
        ),
        actionTextColor: ColorsManager.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusButton),
          side: borderSide,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textAlign: TextAlign.start,
        textStyle: Styles.font12Regular.copyWith(
          fontFamily: fontFamily,
          color: c.textPrimary,
        ),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(Dimens.radiusChip),
          border: Border.fromBorderSide(borderSide),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(minButtonSize),
          shape: WidgetStatePropertyAll(roundedButton),
          side: WidgetStatePropertyAll(borderSide),
          textStyle: WidgetStatePropertyAll(
            Styles.font14Bold.copyWith(fontFamily: fontFamily),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? ColorsManager.primary
                : c.surfaceRaised,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? ColorsManager.onPrimary
                : c.textSecondary,
          ),
          iconColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? ColorsManager.onPrimary
                : c.textSecondary,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(ColorsManager.white),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ColorsManager.primary
              : c.border,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(
          ColorsManager.transparent,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.space4),
        ),
        side: BorderSide(color: c.textMuted, width: Dimens.borderWidth),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ColorsManager.primary
              : ColorsManager.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(ColorsManager.white),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? ColorsManager.primary
              : c.textMuted,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ColorsManager.accent,
        linearTrackColor: c.surfaceRaised,
        circularTrackColor: c.surfaceRaised,
      ),
    );
  }
}
