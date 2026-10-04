import 'package:flutter/widgets.dart';
import 'package:tube_downloader/l10n/app_localizations.dart';

/// `context.l10n.someKey` — every user-facing string goes through this.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
