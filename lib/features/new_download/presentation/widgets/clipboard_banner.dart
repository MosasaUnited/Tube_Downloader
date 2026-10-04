import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/ltr_text.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';

/// "Link detected in clipboard — Use it".
class ClipboardBanner extends StatelessWidget {
  const ClipboardBanner({required this.link, super.key});

  final String link;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final cubit = context.read<LinkInputCubit>();
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Dimens.space16,
          Dimens.space8,
          Dimens.space8,
          Dimens.space8,
        ),
        child: Row(
          children: [
            const Icon(Icons.assignment_outlined, color: ColorsManager.accent),
            horizontalSpace(Dimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.clipboardLinkDetected,
                    style: Styles.font14Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                  LtrText(
                    link,
                    style: Styles.font12Regular.copyWith(
                      color: ColorsManager.accent,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: cubit.dismissSuggestion,
              child: Text(l10n.actionDismiss),
            ),
            FilledButton(
              onPressed: cubit.useSuggestion,
              child: Text(l10n.actionUseIt),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.1, end: 0);
  }
}
