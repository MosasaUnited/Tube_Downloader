import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/features/shell/logic/nav_badge_cubit/nav_badge_cubit.dart';

/// One navigation destination, shared by the bottom bar, the rail and the
/// sidebar so the three can never disagree. Order = shell branch order.
class NavDestination {
  const NavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.title,
    this.showsQueueBadge = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// The page title shown in the top bar / app bar.
  final String title;

  /// Downloads: carries the count of downloads in progress ([NavBadgeCubit]).
  final bool showsQueueBadge;

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
        showsQueueBadge: true,
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

/// A destination's icon for the bottom bar and the rail; the Downloads one
/// carries the in-progress count as a badge.
class NavIcon extends StatelessWidget {
  const NavIcon({required this.destination, required this.selected, super.key});

  final NavDestination destination;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(selected ? destination.selectedIcon : destination.icon);
    if (!destination.showsQueueBadge) return icon;
    final count = context.watch<NavBadgeCubit>().state;
    return Semantics(
      label: count > 0 ? context.l10n.activeDownloadsBadge(count) : null,
      child: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        backgroundColor: ColorsManager.primary,
        textColor: ColorsManager.onPrimary,
        child: icon,
      ),
    );
  }
}
