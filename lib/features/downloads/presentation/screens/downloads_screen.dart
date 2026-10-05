import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/widgets/empty_state.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_cubit.dart';
import 'package:tube_downloader/features/downloads/logic/downloads_cubit/downloads_state.dart';
import 'package:tube_downloader/features/downloads/logic/live_progress_cubit/live_progress_cubit.dart';
import 'package:tube_downloader/features/downloads/presentation/widgets/group_card.dart';
import 'package:tube_downloader/features/downloads/presentation/widgets/queue_status_cards.dart';
import 'package:tube_downloader/features/downloads/presentation/widgets/queue_toolbar.dart';
import 'package:tube_downloader/features/downloads/presentation/widgets/task_card.dart';
import 'package:tube_downloader/features/downloads/presentation/widgets/task_details_view.dart';

/// The Downloads tab. Wide windows: the queue and, beside it, the selected
/// task's details. Phones: the queue; a tap pushes the details screen.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Two providers: the list's durable state and the live bytes are read by
    // both the queue and the details pane, at different rates.
    return MultiBlocProvider(
      providers: [
        BlocProvider<DownloadsCubit>(
          create: (_) => getIt<DownloadsCubit>()..start(),
        ),
        BlocProvider<LiveProgressCubit>(
          create: (_) => getIt<LiveProgressCubit>(),
        ),
      ],
      child: const _DownloadsBody(),
    );
  }
}

class _DownloadsBody extends StatelessWidget {
  const _DownloadsBody();

  @override
  Widget build(BuildContext context) {
    final expanded = windowClassOf(context) == WindowClass.expanded;
    return BlocBuilder<DownloadsCubit, DownloadsState>(
      builder: (context, state) {
        if (!state.loaded) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.countOf(TaskFilter.all) == 0 &&
            state.filter == TaskFilter.all) {
          final l10n = context.l10n;
          return EmptyState(
            icon: Icons.download_outlined,
            title: l10n.emptyDownloadsTitle,
            body: l10n.emptyDownloadsBody,
            actionLabel: l10n.emptyDownloadsAction,
            onAction: () => context.go(AppRoutes.newDownload),
          );
        }
        final queue = _QueueColumn(state: state, wide: expanded);
        if (!expanded) return queue;
        final selected = state.selectedId;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: queue),
            SizedBox(
              width: Dimens.detailsPaneWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(color: context.colors.border),
                  ),
                ),
                child: selected == null
                    ? EmptyState(
                        icon: Icons.info_outline,
                        title: context.l10n.detailsSelectHint,
                      )
                    : TaskDetailsView(taskId: selected),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Health banner, (phones) the summary card, filters, controls, the list.
class _QueueColumn extends StatelessWidget {
  const _QueueColumn({required this.state, required this.wide});

  final DownloadsState state;
  final bool wide;

  void _open(BuildContext context, String taskId) {
    if (wide) {
      context.read<DownloadsCubit>().select(taskId);
    } else {
      context.push(AppRoutes.taskDetails(taskId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final margin = pageMarginOf(context);
    final compact = windowClassOf(context) == WindowClass.compact;
    final items = state.items;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsetsDirectional.fromSTEB(
            margin,
            Dimens.space16,
            margin,
            0,
          ),
          sliver: SliverList.list(
            children: [
              QueueHealthBanner(health: state.health),
              if (compact) ...[
                QueueSummaryCard(state: state),
                verticalSpace(Dimens.space12),
              ],
              QueueFilterBar(state: state),
              verticalSpace(Dimens.space8),
              if (compact)
                const QueueControls()
              else
                const Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: QueueControls(),
                ),
              verticalSpace(Dimens.space8),
            ],
          ),
        ),
        if (items.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.filter_list,
              title: context.l10n.emptyFilteredTitle,
              body: context.l10n.emptyFilteredBody,
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsetsDirectional.fromSTEB(
              margin,
              0,
              margin,
              Dimens.space24,
            ),
            sliver: SliverList.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: Dimens.space8),
                child: switch (items[i]) {
                  TaskQueueItem(:final task) => TaskCard(
                    key: ValueKey(task.id),
                    task: task,
                    selected: wide && task.id == state.selectedId,
                    onTap: () => _open(context, task.id),
                  ),
                  final GroupQueueItem group => GroupCard(
                    key: ValueKey(group.summary.group.id),
                    item: group,
                    expanded: state.expandedGroups.contains(
                      group.summary.group.id,
                    ),
                    selectedId: wide ? state.selectedId : null,
                    onOpenTask: (id) => _open(context, id),
                  ),
                },
              ),
            ),
          ),
      ],
    );
  }
}
