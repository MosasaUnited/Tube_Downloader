import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/format_chip.dart';
import 'package:tube_downloader/core/widgets/ltr_text.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_state.dart';

/// "Paste links, one per line": the multi-line box with its link count and
/// Paste / Import .txt / Clear all. The text lives in [BatchLinksCubit]; this
/// widget only mirrors it into its controller.
class BatchLinksEditor extends StatefulWidget {
  const BatchLinksEditor({super.key});

  @override
  State<BatchLinksEditor> createState() => _BatchLinksEditorState();
}

class _BatchLinksEditorState extends State<BatchLinksEditor> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<BatchLinksCubit>().state.text,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    final failure = await context.read<BatchLinksCubit>().importFile();
    if (mounted && failure != null) showFailureSnackBar(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final cubit = context.read<BatchLinksCubit>();
    final compact = windowClassOf(context) == WindowClass.compact;
    final count = context.select((BatchLinksCubit c) => c.state.items.length);
    final hasText = context.select(
      (BatchLinksCubit c) => c.state.text.isNotEmpty,
    );
    final paste = OutlinedButton.icon(
      onPressed: cubit.paste,
      icon: const Icon(Icons.content_paste),
      label: Text(l10n.actionPaste),
    );
    final import = OutlinedButton.icon(
      onPressed: _import,
      icon: const Icon(Icons.upload_file_outlined),
      label: Text(l10n.actionImportTxt),
    );
    final clear = hasText ? cubit.clear : null;
    return BlocListener<BatchLinksCubit, BatchLinksState>(
      listenWhen: (a, b) => a.text != b.text,
      // Paste, import, drop, remove and clear change the text from outside.
      listener: (context, state) {
        if (_controller.text != state.text) _controller.text = state.text;
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Phones: the title and an icon-only Clear. Wide windows: the
              // title, then every action — on the same line when they fit.
              if (compact)
                Row(
                  children: [
                    Expanded(child: _Title(count: count)),
                    IconButton(
                      tooltip: l10n.actionClearAll,
                      onPressed: clear,
                      icon: const Icon(Icons.clear_all),
                    ),
                  ],
                )
              else
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: Dimens.space16,
                  runSpacing: Dimens.space8,
                  children: [
                    _Title(count: count),
                    Wrap(
                      spacing: Dimens.space8,
                      runSpacing: Dimens.space8,
                      children: [
                        paste,
                        import,
                        TextButton.icon(
                          onPressed: clear,
                          icon: const Icon(Icons.clear_all),
                          label: Text(l10n.actionClearAll),
                        ),
                      ],
                    ),
                  ],
                ),
              verticalSpace(Dimens.space12),
              TextField(
                controller: _controller,
                onChanged: cubit.setText,
                minLines: compact ? 4 : 5,
                maxLines: compact ? 6 : 8,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                textDirection: urlFieldDirection,
                style: Styles.font14Regular.copyWith(color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: l10n.batchHint,
                  hintMaxLines: 2,
                  hintTextDirection: urlFieldDirection,
                ),
              ),
              if (compact) ...[
                verticalSpace(Dimens.space12),
                Row(
                  children: [
                    Expanded(child: paste),
                    horizontalSpace(Dimens.space8),
                    Expanded(child: import),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// "🔗 Paste links, one per line  [5 links]"
class _Title extends StatelessWidget {
  const _Title({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.link, color: ColorsManager.accent),
        horizontalSpace(Dimens.space12),
        Flexible(
          child: Text(
            l10n.batchPasteTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Styles.font16Bold.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
        if (count > 0) ...[
          horizontalSpace(Dimens.space8),
          FormatChip(l10n.batchLinksCount(count), highlighted: true),
        ],
      ],
    );
  }
}
