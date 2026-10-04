import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';

/// One navigation destination, shared by the bottom bar, the rail and the
/// sidebar so the three can never disagree. Order = shell branch order.
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.title,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// The page title shown in the top bar / app bar.
  final String title;

  static List<NavDestination> of(BuildContext context) {
    final l10n = context.l10n;
    return [
      NavDestination(
        icon: Icons.add_circle_outline,
        selectedIcon: Icons.add_circle,
        label: l10n.navNew,
        title: l10n.titleNewDownload,
      ),
      NavDestination(
        icon: Icons.download_outlined,
        selectedIcon: Icons.download,
        label: l10n.navDownloads,
        title: l10n.titleDownloads,
      ),
      NavDestination(
        icon: Icons.video_library_outlined,
        selectedIcon: Icons.video_library,
        label: l10n.navLibrary,
        title: l10n.titleLibrary,
      ),
      NavDestination(
        icon: Icons.settings_outlined,
        selectedIcon: Icons.settings,
        label: l10n.navSettings,
        title: l10n.titleSettings,
      ),
    ];
  }
}
