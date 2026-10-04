import 'package:flutter/material.dart';

/// Every raw colour in the app, named by role. This is the only file allowed a
/// `Color(…)` literal (review-gate). Theme-dependent surfaces and text are read
/// through `context.colors` (AppColors), which picks the dark or light token.
///
/// Values: the Stitch brief's tokens (`../Tube_Downloader_design/*/DESIGN.md`).
abstract final class ColorsManager {
  // ── Brand ────────────────────────────────────────────────────────────────
  static const primary = Color(0xFF6C5CE7);
  static const primaryHover = Color(0xFF5B4BD8);

  /// Download streams, active progress, parsing indicators.
  static const accent = Color(0xFF00C2FF);

  /// Text and icons on a [primary] fill.
  static const onPrimary = Color(0xFFF2F4F8);

  // ── Status (never the only signal: always paired with an icon + label) ───
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF5A524);
  static const error = Color(0xFFEF4444);
  static const paused = Color(0xFF94A3B8);

  // ── Dark theme tokens ────────────────────────────────────────────────────
  static const darkBackground = Color(0xFF0B0D14);
  static const darkSurface = Color(0xFF141824);
  static const darkSurfaceRaised = Color(0xFF1C2130);
  static const darkBorder = Color(0xFF262C3D);
  static const darkTextPrimary = Color(0xFFF2F4F8);
  static const darkTextSecondary = Color(0xFF9AA3B5);
  static const darkTextMuted = Color(0xFF6B7385);
  static const darkPrimaryContainer = Color(0xFF2A2550);

  // ── Light theme tokens ───────────────────────────────────────────────────
  static const lightBackground = Color(0xFFF6F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceRaised = Color(0xFFF0F2F8);
  static const lightBorder = Color(0xFFE3E6EF);
  static const lightTextPrimary = Color(0xFF12141C);
  static const lightTextSecondary = Color(0xFF5B6475);
  static const lightTextMuted = Color(0xFF8A92A3);
  static const lightPrimaryContainer = Color(0xFFECE9FF);

  // ── Overlays ─────────────────────────────────────────────────────────────
  /// Modal / sheet backdrop: the dark canvas at 65 %.
  static const scrim = Color(0xA60B0D14);

  /// Behind the duration badge on a thumbnail (readable on any frame).
  static const thumbnailBadge = Color(0xB3000000);

  static const transparent = Color(0x00000000);
  static const white = Color(0xFFFFFFFF);
}
