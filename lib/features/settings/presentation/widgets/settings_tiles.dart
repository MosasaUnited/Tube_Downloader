import 'package:flutter/material.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/app_theme.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';

/// Saves a setting and reports a failure next to the control just changed.
Future<void> applySetting(
  BuildContext context,
  Future<Result<Object?>> save,
) async {
  final result = await save;
  if (context.mounted && result is Failure<Object?>) {
    showFailureSnackBar(context, result.failure);
  }
}

/// One settings row: icon, title, an optional hint under it, and a trailing
/// control. The trailing control drops under the text when there is no room
/// (large text, narrow phones).
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.subtitleColor,
    this.trailing,
    this.below,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? subtitleColor;
  final Widget? trailing;

  /// A full-width control under the row (segmented buttons, previews).
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final trailing = this.trailing;
    final below = this.below;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Styles.font16Bold.copyWith(color: colors.textPrimary),
        ),
        if (subtitle != null) ...[
          verticalSpace(Dimens.space4),
          Text(
            subtitle!,
            style: Styles.font12Regular.copyWith(
              color: subtitleColor ?? colors.textSecondary,
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimens.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: ColorsManager.accent),
              ),
              horizontalSpace(Dimens.space12),
              Expanded(
                child: trailing == null
                    ? text
                    : Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: Dimens.space12,
                        runSpacing: Dimens.space8,
                        children: [text, trailing],
                      ),
              ),
            ],
          ),
          if (below != null) ...[
            verticalSpace(Dimens.space12),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: Dimens.iconSize + Dimens.space12,
              ),
              child: below,
            ),
          ],
        ],
      ),
    );
  }
}

/// A [SettingsTile] whose whole row toggles a switch.
class SettingsSwitchTile extends StatelessWidget {
  const SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        borderRadius: BorderRadius.circular(Dimens.radiusButton),
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            Expanded(
              child: SettingsTile(icon: icon, title: title, subtitle: subtitle),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

/// A compact bordered dropdown for settings values.
class SettingsDropdown<T> extends StatelessWidget {
  const SettingsDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final T value;

  /// value → label.
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(Dimens.radiusChip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Dimens.space12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: items.containsKey(value) ? value : null,
            isDense: true,
            borderRadius: BorderRadius.circular(Dimens.radiusChip),
            dropdownColor: colors.surfaceRaised,
            // DropdownButton doesn't inherit the app font: set it here.
            style: Styles.font14Bold.copyWith(
              color: ColorsManager.accent,
              fontFamily: AppTheme.fontFamily,
            ),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
            items: [
              for (final entry in items.entries)
                DropdownMenuItem<T>(value: entry.key, child: Text(entry.value)),
            ],
          ),
        ),
      ),
    );
  }
}
