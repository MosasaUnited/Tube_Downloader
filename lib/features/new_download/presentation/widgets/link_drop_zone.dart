import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/platform/window_service.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';

/// Desktop: drop `.txt` lists, `.webloc` or `.url` bookmarks anywhere on the
/// New Download tab. One link opens in its tab; several go to Multiple links.
/// On phones it is just [child].
class LinkDropZone extends StatefulWidget {
  const LinkDropZone({required this.child, super.key});

  final Widget child;

  @override
  State<LinkDropZone> createState() => _LinkDropZoneState();
}

class _LinkDropZoneState extends State<LinkDropZone> {
  // Hover feedback only — what was dropped goes straight to the cubit.
  bool _dragging = false;

  void _setDragging(bool value) {
    if (_dragging != value) setState(() => _dragging = value);
  }

  @override
  Widget build(BuildContext context) {
    if (!WindowService.isDesktop) return widget.child;
    return DropTarget(
      onDragEntered: (_) => _setDragging(true),
      onDragExited: (_) => _setDragging(false),
      onDragDone: (details) {
        _setDragging(false);
        context.read<LinkInputCubit>().receiveFiles(details.files);
      },
      child: Stack(
        children: [
          widget.child,
          if (_dragging) const Positioned.fill(child: _DropOverlay()),
        ],
      ),
    );
  }
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.92),
          border: Border.all(color: ColorsManager.accent, width: 2),
          borderRadius: BorderRadius.circular(Dimens.radiusCard),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.file_download_outlined,
                size: Dimens.space48,
                color: ColorsManager.accent,
              ),
              verticalSpace(Dimens.space12),
              Text(
                context.l10n.dropLinksHere,
                style: Styles.font18Bold.copyWith(color: colors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
