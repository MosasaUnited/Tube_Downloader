import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:tube_downloader/features/downloads/presentation/screens/downloads_screen.dart';
import 'package:tube_downloader/features/downloads/presentation/screens/task_details_screen.dart';
import 'package:tube_downloader/features/library/presentation/screens/library_screen.dart';
import 'package:tube_downloader/features/new_download/presentation/screens/new_download_screen.dart';
import 'package:tube_downloader/features/settings/presentation/screens/settings_screen.dart';
import 'package:tube_downloader/features/shell/presentation/adaptive_shell.dart';

/// Route paths. The four tabs are branches of one StatefulShellRoute, in this
/// order (AdaptiveShell maps branch index ↔ destination).
abstract final class AppRoutes {
  static const newDownload = '/new';
  static const downloads = '/downloads';
  static const library = '/library';
  static const settings = '/settings';

  /// Phones: one download's details, pushed over the tabs.
  static const taskDetailsPattern = '/task/:id';
  static String taskDetails(String id) => '/task/$id';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

/// A fresh router (tests build their own; the app builds one and keeps it).
GoRouter buildAppRouter() => GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.newDownload,
  routes: [
    // indexedStack: each tab keeps its own navigation stack and state.
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AdaptiveShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.newDownload,
              builder: (context, state) => const NewDownloadScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.downloads,
              builder: (context, state) => const DownloadsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.library,
              builder: (context, state) => const LibraryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    // Wide windows show details in the Downloads pane instead.
    GoRoute(
      path: AppRoutes.taskDetailsPattern,
      builder: (context, state) =>
          TaskDetailsScreen(taskId: state.pathParameters['id']!),
    ),
  ],
);
