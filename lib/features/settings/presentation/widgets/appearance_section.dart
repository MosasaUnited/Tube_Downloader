import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/section_card.dart';
import 'package:tube_downloader/features/settings/logic/appearance_cubit/appearance_cubit.dart';
import 'package:tube_downloader/features/settings/logic/appearance_cubit/appearance_state.dart';

/// Theme (System / Light / Dark) and language (English / العربية).
class AppearanceSection extends StatelessWidget {
  const AppearanceSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<AppearanceCubit, AppearanceState>(
      builder: (context, state) {
        final theme = switch (state.themeMode) {
          ThemeMode.system => ThemePreference.system,
          ThemeMode.light => ThemePreference.light,
          ThemeMode.dark => ThemePreference.dark,
        };
        final language =
            state.locale?.languageCode ??
            Localizations.localeOf(context).languageCode;
        return SectionCard(
          title: l10n.settingsAppearance,
          children: [
            _Label(l10n.settingsTheme),
            SegmentedButton<ThemePreference>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemePreference.system,
                  label: Text(l10n.themeSystem),
                  icon: const Icon(Icons.brightness_auto_outlined),
                ),
                ButtonSegment(
                  value: ThemePreference.light,
                  label: Text(l10n.themeLight),
                  icon: const Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemePreference.dark,
                  label: Text(l10n.themeDark),
                  icon: const Icon(Icons.dark_mode_outlined),
                ),
              ],
              selected: {theme},
              onSelectionChanged: (s) => _apply(
                context,
                context.read<AppearanceCubit>().setTheme(s.single),
              ),
            ),
            verticalSpace(Dimens.space24),
            _Label(l10n.settingsLanguage),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'en', label: Text(l10n.languageEnglish)),
                ButtonSegment(value: 'ar', label: Text(l10n.languageArabic)),
              ],
              selected: {language},
              onSelectionChanged: (s) => _apply(
                context,
                context.read<AppearanceCubit>().setLanguage(s.single),
              ),
            ),
          ],
        );
      },
    );
  }

  /// A failed save is reported next to the control that was just changed.
  static Future<void> _apply(
    BuildContext context,
    Future<Result<AppSettings>> save,
  ) async {
    final result = await save;
    if (!context.mounted) return;
    result.whenOrNull(failure: (f) => showFailureSnackBar(context, f));
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Dimens.space8),
      child: Text(
        text,
        style: Styles.font14Bold.copyWith(color: context.colors.textSecondary),
      ),
    );
  }
}
