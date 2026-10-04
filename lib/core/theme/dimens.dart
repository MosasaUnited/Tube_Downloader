/// Sizes from the Stitch design system: radii by component role, the 8px
/// spacing scale and the structural measurements of the shells. Feature code
/// uses these (and `verticalSpace` / `horizontalSpace`), never a magic number.
abstract final class Dimens {
  // Radii by role.
  static const radiusChip = 8.0; // chips, inputs, URL bar, badges
  static const radiusButton = 12.0; // buttons, segmented controls, thumbnails
  static const radiusCard = 16.0; // cards, panes, settings groups
  static const radiusSheet = 24.0; // dialogs, bottom sheets
  static const radiusPill = 999.0; // status pills: fully rounded ends

  // 8px rhythm with 4px half-steps.
  static const space4 = 4.0;
  static const space8 = 8.0;
  static const space12 = 12.0;
  static const space16 = 16.0;
  static const space24 = 24.0;
  static const space32 = 32.0;
  static const space48 = 48.0;

  /// Minimum interactive area (rtl-a11y skill).
  static const touchTarget = 48.0;

  // Shell.
  static const sidebarWidth = 240.0;
  static const railWidth = 72.0;
  static const bottomNavHeight = 64.0;
  static const topBarHeight = 64.0;

  /// Horizontal page margin: 16 on phones, 24 on tablets / desktop.
  static const pageMarginCompact = 16.0;
  static const pageMarginWide = 24.0;

  /// The "Save to" block in a footer bar (its path ellipsizes).
  static const destinationWidth = 300.0;

  /// Readable width cap for forms and option cards on wide windows.
  static const maxContentWidth = 1120.0;

  static const borderWidth = 1.0;
  static const progressTrackHeight = 4.0;
  static const iconSize = 20.0;
  static const iconSmall = 16.0; // inside chips and status lines
}
