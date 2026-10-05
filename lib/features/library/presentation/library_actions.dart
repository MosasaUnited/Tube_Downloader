import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/snackbar_helper.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_cubit.dart';
import 'package:tube_downloader/features/library/presentation/widgets/delete_items_dialog.dart';

/// The Library's actions with their feedback (snackbars, the delete
/// confirmation) — shared by the card menu, the list row and the selection
/// bar so the three behave the same.
abstract final class LibraryActions {
  static Future<void> open(BuildContext context, LibraryItem item) =>
      _report(context, context.read<LibraryCubit>().open(item));

  static Future<void> reveal(BuildContext context, LibraryItem item) =>
      _report(context, context.read<LibraryCubit>().reveal(item));

  static Future<void> copyLink(BuildContext context, LibraryItem item) async {
    await context.read<LibraryCubit>().copyLink(item);
    if (context.mounted) showInfoSnackBar(context, context.l10n.linkCopied);
  }

  /// [anchor] is the tapped widget's context: the share sheet points at it
  /// on iPad.
  static Future<void> share(
    BuildContext context,
    List<LibraryItem> items, {
    BuildContext? anchor,
  }) {
    final box = (anchor ?? context).findRenderObject() as RenderBox?;
    final origin = box == null || !box.hasSize
        ? null
        : box.localToGlobal(Offset.zero) & box.size;
    return _report(
      context,
      context.read<LibraryCubit>().share(items, origin: origin),
    );
  }

  static Future<void> saveToPhotos(
    BuildContext context,
    List<LibraryItem> items,
  ) async {
    final result = await context.read<LibraryCubit>().saveToPhotos(items);
    if (!context.mounted) return;
    switch (result) {
      case Success(:final data):
        showInfoSnackBar(context, context.l10n.savedToPhotos(data));
      case Failure(:final failure):
        showFailureSnackBar(context, failure);
    }
  }

  /// Asks first (with "Also delete from this device"), then deletes.
  static Future<void> delete(
    BuildContext context,
    List<LibraryItem> items,
  ) async {
    final fromDisk = await showDialog<bool>(
      context: context,
      builder: (_) => DeleteItemsDialog(count: items.length),
    );
    if (fromDisk == null || !context.mounted) return;
    final result = await context.read<LibraryCubit>().delete(
      items,
      fromDisk: fromDisk,
    );
    if (!context.mounted) return;
    switch (result) {
      case Success():
        showInfoSnackBar(context, context.l10n.deletedCount(items.length));
      case Failure(:final failure):
        showFailureSnackBar(context, failure);
    }
  }

  static Future<void> _report(
    BuildContext context,
    Future<AppFailure?> run,
  ) async {
    final failure = await run;
    if (context.mounted && failure != null) {
      showFailureSnackBar(context, failure);
    }
  }
}
