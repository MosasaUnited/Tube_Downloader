import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/state_machine/task_state_machine.dart';

void main() {
  test('every status has an entry', () {
    expect(TaskStateMachine.allowed.keys.toSet(), TaskStatus.values.toSet());
  });

  test(
    'exhaustive table: allowed transitions pass, every other one throws',
    () {
      for (final from in TaskStatus.values) {
        for (final to in TaskStatus.values) {
          final allowed = TaskStateMachine.allowed[from]!.contains(to);
          if (allowed) {
            expect(
              () => TaskStateMachine.ensure(from, to),
              returnsNormally,
              reason: '$from → $to',
            );
          } else {
            expect(
              () => TaskStateMachine.ensure(from, to),
              throwsA(isA<IllegalTransitionException>()),
              reason: '$from → $to',
            );
          }
        }
      }
    },
  );

  test('finished tasks never move; FFmpeg steps cannot be paused', () {
    expect(TaskStateMachine.allowed[TaskStatus.completed], isEmpty);
    expect(TaskStateMachine.allowed[TaskStatus.cancelled], isEmpty);
    expect(
      TaskStateMachine.canTransition(TaskStatus.merging, TaskStatus.paused),
      isFalse,
    );
    expect(
      TaskStateMachine.canTransition(TaskStatus.converting, TaskStatus.paused),
      isFalse,
    );
  });

  test('the main paths', () {
    expect(
      TaskStateMachine.canTransition(TaskStatus.queued, TaskStatus.resolving),
      isTrue,
    );
    expect(
      TaskStateMachine.canTransition(
        TaskStatus.downloadingVideo,
        TaskStatus.resolving,
      ),
      isTrue,
      reason: 'expired URL',
    );
    expect(
      TaskStateMachine.canTransition(TaskStatus.failed, TaskStatus.queued),
      isTrue,
      reason: 'retry',
    );
    expect(
      TaskStateMachine.canTransition(TaskStatus.paused, TaskStatus.cancelled),
      isTrue,
    );
  });
}
