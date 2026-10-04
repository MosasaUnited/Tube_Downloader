import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';

/// A titled settings / options group: surface card, 1px border, radius 16.
class SectionCard extends StatelessWidget {
  const SectionCard({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(
            start: Dimens.space4,
            bottom: Dimens.space8,
          ),
          child: Text(
            title.toUpperCase(),
            style: Styles.font12Bold.copyWith(color: colors.textMuted),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(Dimens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
        verticalSpace(Dimens.space24),
      ],
    );
  }
}
