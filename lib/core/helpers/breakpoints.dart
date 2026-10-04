import 'package:flutter/widgets.dart';
import 'package:tube_downloader/core/theme/dimens.dart';

/// Material window-size classes by WIDTH (adaptive-layout skill). Layout
/// structure — shell, panes, column counts — branches on [windowClassOf];
/// a short, wide desktop window is still "expanded".
enum WindowClass { compact, medium, expanded }

const double kCompactMaxWidth = 600;
const double kExpandedMinWidth = 1024;

WindowClass windowClassForWidth(double width) {
  if (width < kCompactMaxWidth) return WindowClass.compact;
  if (width < kExpandedMinWidth) return WindowClass.medium;
  return WindowClass.expanded;
}

WindowClass windowClassOf(BuildContext context) =>
    windowClassForWidth(MediaQuery.sizeOf(context).width);

/// Phone vs tablet hardware, orientation-proof — for component density on
/// mobile, never for the shell structure.
bool isLargeScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= kCompactMaxWidth;

/// Horizontal page margin for the current window.
double pageMarginOf(BuildContext context) =>
    windowClassOf(context) == WindowClass.compact
    ? Dimens.pageMarginCompact
    : Dimens.pageMarginWide;
