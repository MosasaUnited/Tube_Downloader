import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';

/// "Today", "Yesterday", "3 days ago", then the date ("Oct 24").
String relativeDay(BuildContext context, DateTime at) {
  final l10n = context.l10n;
  final today = DateUtils.dateOnly(clock.now());
  final local = at.toLocal();
  final days = today.difference(DateUtils.dateOnly(local)).inDays;
  if (days <= 0) return l10n.dateToday;
  if (days == 1) return l10n.dateYesterday;
  if (days < 7) return l10n.daysAgo(days);
  return formatShortDate(
    local,
    Localizations.localeOf(context).toLanguageTag(),
  );
}
