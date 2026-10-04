import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';

/// The centred "nothing here yet" block: icon, title, body and an optional
/// primary action. Shared by every list screen (Downloads, Library, playlist
/// results) — don't build another (codebase-conventions skill).
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Dimens.space24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  padding: const EdgeInsets.all(Dimens.space16),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: Dimens.space32,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              verticalSpace(Dimens.space16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Styles.font20Bold.copyWith(color: colors.textPrimary),
              ),
              if (body != null) ...[
                verticalSpace(Dimens.space8),
                Text(
                  body!,
                  textAlign: TextAlign.center,
                  style: Styles.font14Regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
              if (actionLabel != null && onAction != null) ...[
                verticalSpace(Dimens.space24),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0),
    );
  }
}
