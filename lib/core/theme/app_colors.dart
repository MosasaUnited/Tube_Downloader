import 'package:flutter/material.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';

/// The theme-dependent colour tokens, switched with the theme mode.
/// Read them as `context.colors.surface`; brand and status colours that do not
/// change between themes come straight from [ColorsManager].
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primaryContainer,
  });

  static const dark = AppColors(
    background: ColorsManager.darkBackground,
    surface: ColorsManager.darkSurface,
    surfaceRaised: ColorsManager.darkSurfaceRaised,
    border: ColorsManager.darkBorder,
    textPrimary: ColorsManager.darkTextPrimary,
    textSecondary: ColorsManager.darkTextSecondary,
    textMuted: ColorsManager.darkTextMuted,
    primaryContainer: ColorsManager.darkPrimaryContainer,
  );

  static const light = AppColors(
    background: ColorsManager.lightBackground,
    surface: ColorsManager.lightSurface,
    surfaceRaised: ColorsManager.lightSurfaceRaised,
    border: ColorsManager.lightBorder,
    textPrimary: ColorsManager.lightTextPrimary,
    textSecondary: ColorsManager.lightTextSecondary,
    textMuted: ColorsManager.lightTextMuted,
    primaryContainer: ColorsManager.lightPrimaryContainer,
  );

  /// Canvas behind everything.
  final Color background;

  /// Cards, panes, app bars, the navigation bar.
  final Color surface;

  /// Hovered / pressed rows, sheets, nested controls.
  final Color surfaceRaised;

  /// The 1px boundary on panels, cards and inputs.
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// Selected chips and the active navigation pill.
  final Color primaryContainer;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceRaised,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primaryContainer,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primaryContainer: primaryContainer ?? this.primaryContainer,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primaryContainer: Color.lerp(
        primaryContainer,
        other.primaryContainer,
        t,
      )!,
    );
  }
}

extension AppColorsContext on BuildContext {
  /// The active theme's tokens. Both `AppTheme.dark` and `AppTheme.light`
  /// register the extension, so this never returns null inside the app.
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
