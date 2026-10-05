import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/snackbar_helper.dart';
import 'package:tube_downloader/core/platform/window_service.dart';
import 'package:tube_downloader/core/widgets/section_card.dart';
import 'package:tube_downloader/features/settings/logic/settings_cubit/settings_cubit.dart';
import 'package:tube_downloader/features/settings/logic/settings_cubit/settings_state.dart';
import 'package:tube_downloader/features/settings/presentation/widgets/settings_tiles.dart';

/// Wi-Fi only (phones — a desktop has no mobile data), copied-link
/// detection, completion notifications.
class BehaviorSection extends StatelessWidget {
  const BehaviorSection({required this.state, super.key});

  final SettingsState state;

  static Future<void> _setNotifications(BuildContext context, bool on) async {
    final cubit = context.read<SettingsCubit>();
    await applySetting(context, cubit.setNotifications(on));
    if (!on || !context.mounted) return;
    final allowed = await cubit.requestNotificationPermission();
    if (!allowed && context.mounted) {
      showInfoSnackBar(context, context.l10n.notificationsBlocked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SettingsCubit>();
    final s = state.settings;
    return SectionCard(
      title: l10n.settingsBehavior,
      children: [
        if (!WindowService.isDesktop)
          SettingsSwitchTile(
            icon: Icons.wifi,
            title: l10n.settingsWifiOnly,
            subtitle: l10n.settingsWifiOnlyHint,
            value: s.wifiOnly,
            onChanged: (v) => applySetting(context, cubit.setWifiOnly(v)),
          ),
        SettingsSwitchTile(
          icon: Icons.content_paste_search,
          title: l10n.settingsClipboard,
          subtitle: l10n.settingsClipboardHint,
          value: s.clipboardWatch,
          onChanged: (v) => applySetting(context, cubit.setClipboardWatch(v)),
        ),
        SettingsSwitchTile(
          icon: Icons.notifications_outlined,
          title: l10n.settingsNotifications,
          subtitle: l10n.settingsNotificationsHint,
          value: s.notifications,
          onChanged: (v) => _setNotifications(context, v),
        ),
      ],
    );
  }
}

/// The app's name and the open-source licences page (Flutter's, which lists
/// every package's licence).
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SectionCard(
      title: l10n.settingsAbout,
      children: [
        InkWell(
          onTap: () =>
              showLicensePage(context: context, applicationName: l10n.appTitle),
          child: SettingsTile(
            icon: Icons.description_outlined,
            title: l10n.settingsLicenses,
            // Mirrors itself in Arabic (matchTextDirection).
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      ],
    );
  }
}
