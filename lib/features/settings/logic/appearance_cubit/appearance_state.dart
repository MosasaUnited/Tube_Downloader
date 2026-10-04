import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'appearance_state.freezed.dart';

/// What `MaterialApp` needs to render: theme mode and locale (null = follow
/// the device).
@freezed
abstract class AppearanceState with _$AppearanceState {
  const factory AppearanceState({
    required ThemeMode themeMode,
    Locale? locale,
  }) = _AppearanceState;
}
