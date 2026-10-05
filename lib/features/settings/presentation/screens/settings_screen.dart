import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/features/settings/logic/settings_cubit/settings_cubit.dart';
import 'package:tube_downloader/features/settings/logic/settings_cubit/settings_state.dart';
import 'package:tube_downloader/features/settings/presentation/widgets/appearance_section.dart';
import 'package:tube_downloader/features/settings/presentation/widgets/behavior_section.dart';
import 'package:tube_downloader/features/settings/presentation/widgets/downloads_section.dart';
import 'package:tube_downloader/features/settings/presentation/widgets/storage_card.dart';

/// Settings: storage, downloads, network & behaviour, appearance, about.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SettingsCubit>(
      create: (_) => getIt<SettingsCubit>()..start(),
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final margin = pageMarginOf(context);
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: ConstrainedBox(
        // Option rows read badly stretched across a 1400px window.
        constraints: const BoxConstraints(maxWidth: 720),
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) => RefreshIndicator(
            // Pull down to re-read free space.
            onRefresh: context.read<SettingsCubit>().refreshStorage,
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: margin,
                vertical: Dimens.space24,
              ),
              children: [
                StorageCard(space: state.space),
                verticalSpace(Dimens.space24),
                DownloadsSection(state: state),
                BehaviorSection(state: state),
                const AppearanceSection(),
                const AboutSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
