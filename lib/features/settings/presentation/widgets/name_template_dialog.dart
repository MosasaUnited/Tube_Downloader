import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:tube_downloader/core/download_core/domain/naming/file_name_template.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/ltr_text.dart';

/// The file name a [template] gives a sample video ("…mp4"), for previews.
String previewFileName(BuildContext context, String template) {
  final l10n = context.l10n;
  final base = FileNameTemplate.render(
    template,
    title: l10n.templateSampleTitle,
    channel: l10n.templateSampleChannel,
    videoId: 'aqz-KE-bpKQ',
    quality: '1080p',
    index: 3,
    date: clock.now(),
  );
  return '$base.mp4';
}

/// Edits the file-name pattern: fields as chips, a live preview, unknown
/// fields rejected. Pops the new pattern, or null when cancelled.
class NameTemplateDialog extends StatefulWidget {
  const NameTemplateDialog({required this.initial, super.key});

  final String initial;

  @override
  State<NameTemplateDialog> createState() => _NameTemplateDialogState();
}

class _NameTemplateDialogState extends State<NameTemplateDialog> {
  // The text being edited: the dialog's own UI state until Save.
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Inserts `{field}` at the cursor (or the end).
  void _insert(String field) {
    final value = _controller.value;
    final at = value.selection.isValid
        ? value.selection.start
        : value.text.length;
    final end = value.selection.isValid ? value.selection.end : at;
    final token = '{$field}';
    _controller.value = TextEditingValue(
      text: value.text.replaceRange(at, end, token),
      selection: TextSelection.collapsed(offset: at + token.length),
    );
  }

  String? _error(BuildContext context, String text) {
    final l10n = context.l10n;
    if (text.trim().isEmpty) return l10n.templateEmpty;
    final unknown = FileNameTemplate.unknownPlaceholders(text);
    return unknown.isEmpty
        ? null
        : l10n.templateUnknown(unknown.map((f) => '{$f}').join(', '));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final fields = {
      'title': l10n.fieldTitle,
      'channel': l10n.fieldChannel,
      'quality': l10n.fieldQuality,
      'date': l10n.fieldDate,
      'index': l10n.fieldIndex,
      'id': l10n.fieldId,
    };
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        final error = _error(context, value.text);
        return AlertDialog(
          title: Text(l10n.templateTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.templateHelp,
                  style: Styles.font14Regular.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
                verticalSpace(Dimens.space12),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  autocorrect: false,
                  // Tokens and separators read left to right, like a path.
                  textDirection: urlFieldDirection,
                  decoration: InputDecoration(errorText: error),
                ),
                verticalSpace(Dimens.space12),
                Wrap(
                  spacing: Dimens.space8,
                  runSpacing: Dimens.space8,
                  children: [
                    for (final entry in fields.entries)
                      ActionChip(
                        label: Text(entry.value),
                        onPressed: () => _insert(entry.key),
                      ),
                  ],
                ),
                verticalSpace(Dimens.space16),
                if (error == null)
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        size: Dimens.iconSmall,
                        color: ColorsManager.success,
                      ),
                      horizontalSpace(Dimens.space8),
                      Expanded(
                        child: LtrText(
                          previewFileName(context, value.text),
                          maxLines: 2,
                          style: Styles.font14Regular.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  _controller.text = FileNameTemplate.defaultTemplate,
              child: Text(l10n.actionReset),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: error == null
                  ? () => Navigator.of(context).pop(value.text.trim())
                  : null,
              child: Text(l10n.actionSave),
            ),
          ],
        );
      },
    );
  }
}
