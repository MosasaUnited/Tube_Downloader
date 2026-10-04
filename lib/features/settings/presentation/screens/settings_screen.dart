import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/features/settings/presentation/widgets/appearance_section.dart';

/// Settings tab. Phase 1 has Appearance; Phase 6 adds the other sections.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final margin = pageMarginOf(context);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        // Option rows read badly stretched across a 1400px window.
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: margin,
            vertical: Dimens.space24,
          ),
          children: const [AppearanceSection()],
        ),
      ),
    );
  }
}
