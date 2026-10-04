import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/widgets/ltr_text.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_state.dart';

/// The link field with Paste and Fetch. The text lives in [LinkInputCubit];
/// this widget only mirrors it into its controller.
class UrlInputBar extends StatefulWidget {
  const UrlInputBar({super.key});

  @override
  State<UrlInputBar> createState() => _UrlInputBarState();
}

class _UrlInputBarState extends State<UrlInputBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: context.read<LinkInputCubit>().state.text,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final compact = windowClassOf(context) == WindowClass.compact;
    return BlocConsumer<LinkInputCubit, LinkInputState>(
      listenWhen: (a, b) => a.text != b.text,
      // Paste / clipboard / "Use it" change the text from outside the field.
      listener: (context, state) {
        if (_controller.text != state.text) _controller.text = state.text;
      },
      buildWhen: (a, b) => a.canFetch != b.canFetch,
      builder: (context, state) {
        final cubit = context.read<LinkInputCubit>();
        final field = TextField(
          controller: _controller,
          onChanged: cubit.setText,
          onSubmitted: (_) => cubit.fetch(),
          keyboardType: TextInputType.url,
          autocorrect: false,
          textDirection: urlFieldDirection,
          textInputAction: TextInputAction.go,
          decoration: InputDecoration(
            hintText: l10n.newDownloadHint,
            prefixIcon: const Icon(Icons.link, color: ColorsManager.accent),
          ),
        );
        final paste = OutlinedButton.icon(
          onPressed: cubit.paste,
          icon: const Icon(Icons.content_paste),
          label: Text(l10n.actionPaste),
        );
        final fetch = FilledButton.icon(
          onPressed: state.canFetch ? cubit.fetch : null,
          icon: const Icon(Icons.sync),
          label: Text(l10n.actionFetch),
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              verticalSpace(Dimens.space8),
              Row(
                children: [
                  Expanded(child: paste),
                  horizontalSpace(Dimens.space8),
                  Expanded(child: fetch),
                ],
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: field),
            horizontalSpace(Dimens.space8),
            paste,
            horizontalSpace(Dimens.space8),
            fetch,
          ],
        );
      },
    );
  }
}
