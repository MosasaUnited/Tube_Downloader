import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/styles.dart';

/// "Delete 3 files?" with "Also delete from this device" (on by default).
/// Pops true / false for that choice, or null when cancelled.
class DeleteItemsDialog extends StatefulWidget {
  const DeleteItemsDialog({required this.count, super.key});

  final int count;

  @override
  State<DeleteItemsDialog> createState() => _DeleteItemsDialogState();
}

class _DeleteItemsDialogState extends State<DeleteItemsDialog> {
  // The dialog's own checkbox: local UI state, not business state.
  bool _fromDisk = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.deleteTitle(widget.count)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.deleteBody,
            style: Styles.font14Regular.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          CheckboxListTile(
            value: _fromDisk,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n.deleteFromDisk),
            onChanged: (v) => setState(() => _fromDisk = v ?? true),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: ColorsManager.error),
          onPressed: () => Navigator.of(context).pop(_fromDisk),
          child: Text(l10n.actionDelete),
        ),
      ],
    );
  }
}
