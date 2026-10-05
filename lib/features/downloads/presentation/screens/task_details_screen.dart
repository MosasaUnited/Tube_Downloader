import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/features/downloads/logic/live_progress_cubit/live_progress_cubit.dart';
import 'package:tube_downloader/features/downloads/presentation/widgets/task_details_view.dart';

/// Phones: one download's details, pushed over the tabs.
class TaskDetailsScreen extends StatelessWidget {
  const TaskDetailsScreen({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.detailsTitle)),
      body: BlocProvider<LiveProgressCubit>(
        create: (_) => getIt<LiveProgressCubit>(),
        child: TaskDetailsView(taskId: taskId),
      ),
    );
  }
}
