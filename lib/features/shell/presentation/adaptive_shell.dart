import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/features/shell/presentation/widgets/app_sidebar.dart';
import 'package:tube_downloader/features/shell/presentation/widgets/nav_destinations.dart';
import 'package:tube_downloader/features/shell/presentation/widgets/theme_toggle_button.dart';

/// The app frame around the four tabs (adaptive-layout skill):
/// compact → bottom navigation; medium → 72px rail; expanded → 240px sidebar
/// that collapses to the rail. Branches on WIDTH only.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  /// Re-selecting the current tab returns it to its first page.
  void _select(int index) =>
      shell.goBranch(index, initialLocation: index == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final destinations = NavDestination.of(context);
    final current = destinations[shell.currentIndex];
    return switch (windowClassOf(context)) {
      WindowClass.compact => _BottomNavLayout(
        shell: shell,
        destinations: destinations,
        title: current.title,
        onSelect: _select,
      ),
      WindowClass.medium => _SideNavLayout(
        shell: shell,
        destinations: destinations,
        title: current.title,
        onSelect: _select,
        canExtend: false,
      ),
      WindowClass.expanded => _SideNavLayout(
        shell: shell,
        destinations: destinations,
        title: current.title,
        onSelect: _select,
        canExtend: true,
      ),
    };
  }
}

class _BottomNavLayout extends StatelessWidget {
  const _BottomNavLayout({
    required this.shell,
    required this.destinations,
    required this.title,
    required this.onSelect,
  });

  final StatefulNavigationShell shell;
  final List<NavDestination> destinations;
  final String title;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colors.background,
        surfaceTintColor: colors.background,
        titleSpacing: Dimens.pageMarginCompact,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.appTitle,
              style: Styles.font18Bold.copyWith(color: colors.textPrimary),
            ),
            Text(
              title,
              style: Styles.font12Regular.copyWith(color: colors.textSecondary),
            ),
          ],
        ),
        actions: const [ThemeToggleButton()],
      ),
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.border)),
        ),
        child: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: onSelect,
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
          ],
        ),
      ),
    );
  }
}

/// Rail (medium) or collapsible sidebar (expanded) + top bar + content.
class _SideNavLayout extends StatefulWidget {
  const _SideNavLayout({
    required this.shell,
    required this.destinations,
    required this.title,
    required this.onSelect,
    required this.canExtend,
  });

  final StatefulNavigationShell shell;
  final List<NavDestination> destinations;
  final String title;
  final ValueChanged<int> onSelect;
  final bool canExtend;

  @override
  State<_SideNavLayout> createState() => _SideNavLayoutState();
}

class _SideNavLayoutState extends State<_SideNavLayout> {
  // Purely local UI state (sidebar width), so setState is the right tool.
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final extended = widget.canExtend && !_collapsed;
    return Scaffold(
      body: Row(
        children: [
          if (extended)
            AppSidebar(
              destinations: widget.destinations,
              selectedIndex: widget.shell.currentIndex,
              onSelect: widget.onSelect,
              onCollapse: () => setState(() => _collapsed = true),
            )
          else
            NavigationRail(
              minWidth: Dimens.railWidth,
              labelType: NavigationRailLabelType.all,
              selectedIndex: widget.shell.currentIndex,
              onDestinationSelected: widget.onSelect,
              leading: widget.canExtend
                  ? _ExpandButton(
                      onPressed: () => setState(() => _collapsed = false),
                    )
                  : null,
              destinations: [
                for (final d in widget.destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.label),
                  ),
              ],
            ),
          VerticalDivider(width: Dimens.borderWidth, color: colors.border),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: widget.title),
                Expanded(child: widget.shell),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Re-opens the sidebar from the collapsed rail. A sideways chevron implies
/// reading direction (rtl-a11y skill): "expand" points toward the END edge,
/// right in English and left in Arabic.
class _ExpandButton extends StatelessWidget {
  const _ExpandButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Dimens.space8),
      child: IconButton(
        tooltip: context.l10n.expandSidebar,
        icon: Icon(
          isRtl
              ? Icons.keyboard_double_arrow_left
              : Icons.keyboard_double_arrow_right,
        ),
        onPressed: onPressed,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: Dimens.topBarHeight),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: Dimens.pageMarginWide,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Styles.font24Bold.copyWith(color: colors.textPrimary),
            ),
          ),
          const ThemeToggleButton(),
        ],
      ),
    );
  }
}
