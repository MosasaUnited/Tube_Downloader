import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
// For the generated whenOrNull extension on Result.
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/features/settings/logic/appearance_cubit/appearance_cubit.dart';

/// Flips between light and dark (from "system", it flips what is on screen).
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: isDark ? context.l10n.themeLight : context.l10n.themeDark,
      icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () async {
        final result = await context.read<AppearanceCubit>().setTheme(
          isDark ? ThemePreference.light : ThemePreference.dark,
        );
        if (!context.mounted) return;
        result.whenOrNull(failure: (f) => showFailureSnackBar(context, f));
      },
    );
  }
}
