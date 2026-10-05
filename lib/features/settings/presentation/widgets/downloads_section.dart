import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/ltr_text.dart';
import 'package:tube_downloader/core/widgets/section_card.dart';
import 'package:tube_downloader/features/settings/logic/settings_cubit/settings_cubit.dart';
import 'package:tube_downloader/features/settings/logic/settings_cubit/settings_state.dart';
import 'package:tube_downloader/features/settings/presentation/widgets/name_template_dialog.dart';
import 'package:tube_downloader/features/settings/presentation/widgets/settings_tiles.dart';

/// Where files go, the default format and qualities, how many downloads run
/// at once, file names and playlist folders.
class DownloadsSection extends StatelessWidget {
  const DownloadsSection({required this.state, super.key});

  final SettingsState state;

  static const _heights = [2160, 1440, 1080, 720, 480, 360];
  static const _bitrates = [320, 192, 128];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SettingsCubit>();
    final s = state.settings;
    return SectionCard(
      title: l10n.settingsDownloads,
      children: [
        _SaveLocation(state: state),
        SettingsTile(
          icon: Icons.movie_filter_outlined,
          title: l10n.settingsDefaultFormat,
          below: SegmentedButton<MediaKind>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: MediaKind.video,
                icon: const Icon(Icons.videocam_outlined),
                label: Text(l10n.formatVideoAudio),
              ),
              ButtonSegment(
                value: MediaKind.audio,
                icon: const Icon(Icons.music_note_outlined),
                label: Text(l10n.formatAudioOnly),
              ),
            ],
            selected: {s.defaultKind},
            onSelectionChanged: (k) =>
                applySetting(context, cubit.setDefaultKind(k.single)),
          ),
        ),
        SettingsTile(
          icon: Icons.high_quality_outlined,
          title: l10n.settingsVideoQuality,
          subtitle: l10n.settingsVideoQualityHint,
          trailing: SettingsDropdown<int>(
            value: s.defaultMaxHeight,
            items: {for (final h in _heights) h: '${h}p'},
            onChanged: (h) =>
                applySetting(context, cubit.setDefaultMaxHeight(h)),
          ),
        ),
        SettingsTile(
          icon: Icons.graphic_eq,
          title: l10n.settingsAudioQuality,
          trailing: SettingsDropdown<int>(
            value: s.audioKbps,
            items: {for (final k in _bitrates) k: formatBitrate(k)},
            onChanged: (k) => applySetting(context, cubit.setAudioKbps(k)),
          ),
        ),
        SettingsTile(
          icon: Icons.stacked_line_chart,
          title: l10n.settingsConcurrent,
          subtitle: s.maxConcurrent > 3 ? l10n.settingsConcurrentHint : null,
          subtitleColor: ColorsManager.warning,
          trailing: _Stepper(value: s.maxConcurrent),
        ),
        SettingsTile(
          icon: Icons.drive_file_rename_outline,
          title: l10n.settingsNaming,
          trailing: TextButton(
            onPressed: () => _editTemplate(context, s.nameTemplate),
            child: Text(l10n.actionEdit),
          ),
          below: _TemplatePreview(template: s.nameTemplate),
        ),
        SettingsSwitchTile(
          icon: Icons.create_new_folder_outlined,
          title: l10n.settingsPlaylistFolders,
          subtitle: l10n.settingsPlaylistFoldersHint,
          value: s.playlistSubfolders,
          onChanged: (v) =>
              applySetting(context, cubit.setPlaylistSubfolders(v)),
        ),
      ],
    );
  }

  static Future<void> _editTemplate(
    BuildContext context,
    String current,
  ) async {
    final template = await showDialog<String>(
      context: context,
      builder: (_) => NameTemplateDialog(initial: current),
    );
    if (template == null || !context.mounted) return;
    await applySetting(
      context,
      context.read<SettingsCubit>().setNameTemplate(template),
    );
  }
}

class _SaveLocation extends StatelessWidget {
  const _SaveLocation({required this.state});

  final SettingsState state;

  Future<void> _pick(BuildContext context) async {
    final failure = await context.read<SettingsCubit>().pickFolder();
    if (context.mounted && failure != null) {
      showFailureSnackBar(context, failure);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SettingsCubit>();
    final folder = state.saveDirectory;
    if (!cubit.canPickFolder) {
      return SettingsTile(
        icon: Icons.folder_outlined,
        title: l10n.settingsSaveLocation,
        // Fixed by the platform: say where files go.
        subtitle: defaultTargetPlatform == TargetPlatform.android
            ? l10n.settingsSaveLocationAndroid
            : l10n.settingsSaveLocationIos,
      );
    }
    return SettingsTile(
      icon: Icons.folder_outlined,
      title: l10n.settingsSaveLocation,
      trailing: Wrap(
        spacing: Dimens.space4,
        children: [
          if (state.settings.saveDirectory != null)
            TextButton(
              onPressed: () => applySetting(context, cubit.resetFolder()),
              child: Text(l10n.settingsUseDefaultFolder),
            ),
          OutlinedButton(
            onPressed: () => _pick(context),
            child: Text(l10n.settingsChangeFolder),
          ),
        ],
      ),
      below: folder == null
          ? null
          : LtrText(
              folder,
              maxLines: 2,
              style: Styles.font14Regular.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
    );
  }
}

/// − 3 +  (1…5)
class _Stepper extends StatelessWidget {
  const _Stepper({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SettingsCubit>();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          tooltip: l10n.actionDecrease,
          onPressed: value <= AppSettings.minConcurrent
              ? null
              : () => applySetting(context, cubit.setMaxConcurrent(value - 1)),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: Dimens.space32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: Styles.font18Bold.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
        IconButton.outlined(
          tooltip: l10n.actionIncrease,
          onPressed: value >= AppSettings.maxConcurrentLimit
              ? null
              : () => applySetting(context, cubit.setMaxConcurrent(value + 1)),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// "{title} - {channel}" and what it gives: "✓ Ocean Sunrise… .mp4".
class _TemplatePreview extends StatelessWidget {
  const _TemplatePreview({required this.template});

  final String template;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Dimens.radiusButton),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LtrText(
              template,
              style: Styles.font14Bold.copyWith(color: ColorsManager.accent),
            ),
            verticalSpace(Dimens.space4),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: Dimens.iconSmall,
                  color: ColorsManager.success,
                ),
                horizontalSpace(Dimens.space8),
                Expanded(
                  child: Text(
                    context.l10n.settingsNamingPreview(
                      previewFileName(context, template),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Styles.font12Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
