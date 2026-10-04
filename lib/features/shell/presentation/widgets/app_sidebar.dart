import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/features/shell/presentation/widgets/nav_destinations.dart';

/// The 240px desktop sidebar from the design: full-width rows, the selected
/// one filled with the brand violet. Collapses to the 72px NavigationRail
/// (see AdaptiveShell); the collapse arrow points to the start edge.
class AppSidebar extends StatelessWidget {
  const AppSidebar({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.onCollapse,
    super.key,
  });

  final List<NavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onCollapse;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      width: Dimens.sidebarWidth,
      color: colors.surface,
      padding: const EdgeInsets.all(Dimens.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              horizontalSpace(Dimens.space4),
              Expanded(
                child: Text(
                  context.l10n.appTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Styles.font18Bold.copyWith(color: colors.textPrimary),
                ),
              ),
              IconButton(
                tooltip: context.l10n.collapseSidebar,
                // Points to the start edge: left in English, right in Arabic.
                icon: Icon(
                  isRtl
                      ? Icons.keyboard_double_arrow_right
                      : Icons.keyboard_double_arrow_left,
                ),
                onPressed: onCollapse,
              ),
            ],
          ),
          verticalSpace(Dimens.space16),
          for (final (index, destination) in destinations.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: Dimens.space4),
              child: _SidebarItem(
                destination: destination,
                selected: index == selectedIndex,
                onTap: () => onSelect(index),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected
        ? ColorsManager.onPrimary
        : colors.textSecondary;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? ColorsManager.primary : ColorsManager.transparent,
        borderRadius: BorderRadius.circular(Dimens.radiusButton),
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimens.radiusButton),
          hoverColor: colors.surfaceRaised,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: Dimens.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Dimens.space12),
              child: Row(
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    color: foreground,
                    size: Dimens.iconSize + 2,
                  ),
                  horizontalSpace(Dimens.space12),
                  Expanded(
                    child: Text(
                      destination.label,
                      style:
                          (selected ? Styles.font16Bold : Styles.font16Regular)
                              .copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
