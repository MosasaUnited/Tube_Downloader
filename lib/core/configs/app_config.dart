/// Per-flavour behaviour, chosen by the entry point (`main_dev.dart` /
/// `main_prod.dart`) and registered in DI. Branch on this object — never on a
/// compile-time `const` or `kDebugMode` — so the two flavours stay one code path.
class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.appName,
    required this.verboseLogging,
  });

  const AppConfig.development()
    : flavor = AppFlavor.development,
      appName = 'Tube Downloader Dev',
      verboseLogging = true;

  const AppConfig.production()
    : flavor = AppFlavor.production,
      appName = 'Tube Downloader',
      verboseLogging = false;

  final AppFlavor flavor;

  /// Shown where the OS does not already label the app (desktop window title).
  final String appName;

  /// Gates the global `debugPrint` hook (see `installLoggingPolicy`). Off in
  /// production: engine diagnostics carry stream URLs, which are tied to the
  /// user's IP address and must not land in a shared log.
  final bool verboseLogging;
}

enum AppFlavor { development, production }
