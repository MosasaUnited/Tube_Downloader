import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/download_core/domain/state_machine/task_state_machine.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:uuid/uuid.dart';

/// [DownloadRepo] on drift.
class DownloadRepoImpl implements DownloadRepo {
  DownloadRepoImpl(
    this._db, {
    this._clock = const Clock(),
    String Function()? newId,
  }) : _newId = newId ?? const Uuid().v4;

  final AppDatabase _db;
  final Clock _clock;
  final String Function() _newId;

  static const _activeStatuses = {
    TaskStatus.resolving,
    TaskStatus.downloadingVideo,
    TaskStatus.downloadingAudio,
    TaskStatus.merging,
    TaskStatus.converting,
  };

  static Set<TaskStatus> _statusesFor(TaskFilter filter) => switch (filter) {
    // Cancelled tasks never show; "clear" removes them.
    TaskFilter.all => TaskStatus.values.toSet()..remove(TaskStatus.cancelled),
    TaskFilter.active => _activeStatuses,
    TaskFilter.queued => {TaskStatus.queued},
    TaskFilter.paused => {TaskStatus.paused},
    TaskFilter.completed => {TaskStatus.completed},
    TaskFilter.failed => {TaskStatus.failed},
  };

  @override
  Future<Result<List<String>>> enqueue(
    List<DownloadRequest> requests, {
    DownloadGroup? group,
  }) async {
    try {
      final ids = await _db.transaction(() async {
        final now = _clock.now();
        if (group != null) {
          await _db
              .into(_db.downloadGroups)
              .insert(
                DownloadGroupsCompanion.insert(
                  id: group.id,
                  playlistId: group.playlistId,
                  title: group.title,
                  channel: Value(group.channel),
                  subDir: Value(group.subDir),
                  total: group.total,
                  createdAt: now,
                ),
              );
        }
        final maxPosition = _db.downloadTasks.position.max();
        final last =
            await (_db.selectOnly(_db.downloadTasks)..addColumns([maxPosition]))
                .map((r) => r.read(maxPosition))
                .getSingle();
        var position = (last ?? -1) + 1;
        final ids = <String>[];
        for (final request in requests) {
          final id = _newId();
          final media = request.media;
          await _db
              .into(_db.downloadTasks)
              .insert(
                DownloadTasksCompanion.insert(
                  id: id,
                  groupId: Value(group?.id),
                  position: position++,
                  playlistIndex: Value(request.playlistIndex),
                  sourceUrl: media.url,
                  videoId: media.videoId,
                  title: media.title,
                  channel: media.channel,
                  durationMs: Value(media.duration?.inMilliseconds),
                  thumbUrl: Value(media.thumbnailUrl),
                  formatJson: jsonEncode(request.format.toJson()),
                  formatKey: request.format.key,
                  status: TaskStatus.queued,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          await _insertEvent(
            DownloadEvent(taskId: id, type: EventType.requested, at: now),
          );
          ids.add(id);
        }
        return ids;
      });
      return Result.success(ids);
    } on Object catch (e, s) {
      return Result.failure(FailureMapper.map(e, s));
    }
  }

  // ── reads ────────────────────────────────────────────────────────────────

  JoinedSelectStatement<HasResultSet, dynamic> _tasksJoin() =>
      _db.select(_db.downloadTasks).join([
        leftOuterJoin(
          _db.taskLegs,
          _db.taskLegs.taskId.equalsExp(_db.downloadTasks.id),
        ),
      ]);

  /// Rows of (task, leg?) → tasks with their legs, keeping the query's task
  /// order. Legs are put in DOWNLOAD order (LegKind declaration order: video,
  /// audio, muxed) here, for every query — SQL would sort the stored enum
  /// names alphabetically.
  List<DownloadTask> _group(List<TypedResult> rows) {
    final tasks = <String, DownloadTaskRow>{};
    final legs = <String, List<TaskLegRow>>{};
    for (final row in rows) {
      final task = row.readTable(_db.downloadTasks);
      tasks.putIfAbsent(task.id, () => task);
      final leg = row.readTableOrNull(_db.taskLegs);
      if (leg != null) (legs[task.id] ??= []).add(leg);
    }
    return [
      for (final t in tasks.values)
        _toTask(
          t,
          (legs[t.id] ?? <TaskLegRow>[])
            ..sort((a, b) => a.kind.index.compareTo(b.kind.index)),
        ),
    ];
  }

  @override
  Stream<List<DownloadTask>> watchTasks(TaskFilter filter) {
    final query = _tasksJoin()
      ..where(
        _db.downloadTasks.status.isIn(_statusesFor(filter).map((s) => s.name)),
      )
      ..orderBy([OrderingTerm.asc(_db.downloadTasks.position)]);
    return query.watch().map(_group);
  }

  @override
  Stream<DownloadTask?> watchTask(String id) {
    final query = _tasksJoin()..where(_db.downloadTasks.id.equals(id));
    return query.watch().map((rows) => _group(rows).firstOrNull);
  }

  @override
  Future<DownloadTask?> task(String id) async {
    final query = _tasksJoin()..where(_db.downloadTasks.id.equals(id));
    return _group(await query.get()).firstOrNull;
  }

  @override
  Future<DownloadGroup?> group(String id) async {
    final g = await (_db.select(
      _db.downloadGroups,
    )..where((r) => r.id.equals(id))).getSingleOrNull();
    return g == null
        ? null
        : DownloadGroup(
            id: g.id,
            playlistId: g.playlistId,
            title: g.title,
            total: g.total,
            channel: g.channel,
            subDir: g.subDir,
          );
  }

  @override
  Future<List<DownloadTask>> tasksWithStatus(Set<TaskStatus> statuses) async {
    final query = _tasksJoin()
      ..where(_db.downloadTasks.status.isIn(statuses.map((s) => s.name)))
      ..orderBy([OrderingTerm.asc(_db.downloadTasks.position)]);
    return _group(await query.get());
  }

  @override
  Future<DownloadTask?> nextRunnable(
    DateTime now, {
    Set<String> running = const {},
  }) async {
    final t = _db.downloadTasks;
    final row =
        await (_db.select(t)
              ..where(
                (r) =>
                    r.status.equalsValue(TaskStatus.queued) &
                    (r.notBefore.isNull() |
                        r.notBefore.isSmallerOrEqualValue(now)) &
                    r.id.isNotIn(running),
              )
              ..orderBy([(r) => OrderingTerm.asc(r.position)])
              ..limit(1))
            .getSingleOrNull();
    return row == null ? null : task(row.id);
  }

  @override
  Stream<List<GroupSummary>> watchGroups() {
    final active = _activeStatuses.map((s) => "'${s.name}'").join(',');
    return _db
        .customSelect(
          'SELECT g.*, '
          "COALESCE(SUM(t.status = 'completed'), 0) AS n_completed, "
          "COALESCE(SUM(t.status = 'failed'), 0) AS n_failed, "
          'COALESCE(SUM(t.status IN ($active)), 0) AS n_active '
          'FROM download_groups g LEFT JOIN download_tasks t ON t.group_id = g.id '
          'GROUP BY g.id ORDER BY g.created_at',
          readsFrom: {_db.downloadGroups, _db.downloadTasks},
        )
        .watch()
        .map(
          (rows) => [
            for (final r in rows)
              GroupSummary(
                group: DownloadGroup(
                  id: r.read<String>('id'),
                  playlistId: r.read<String>('playlist_id'),
                  title: r.read<String>('title'),
                  total: r.read<int>('total'),
                  channel: r.readNullable<String>('channel'),
                  subDir: r.readNullable<String>('sub_dir'),
                ),
                completed: r.read<int>('n_completed'),
                failed: r.read<int>('n_failed'),
                active: r.read<int>('n_active'),
              ),
          ],
        );
  }

  @override
  Stream<List<DownloadEvent>> watchEvents(String taskId) {
    final e = _db.taskEvents;
    return (_db.select(e)
          ..where((r) => r.taskId.equals(taskId))
          ..orderBy([
            (r) => OrderingTerm.asc(r.at),
            (r) => OrderingTerm.asc(r.id),
          ]))
        .watch()
        .map((rows) => [for (final r in rows) _toEvent(r)]);
  }

  @override
  Future<Set<String>> existingKeys(
    Iterable<(String videoId, String formatKey)> keys,
  ) async {
    final wanted = {for (final (v, f) in keys) '$v|$f'};
    if (wanted.isEmpty) return {};
    final t = _db.downloadTasks;
    final rows =
        await (_db.select(t)..where(
              (r) =>
                  r.videoId.isIn(keys.map((k) => k.$1)) &
                  r.status.equalsValue(TaskStatus.cancelled).not(),
            ))
            .get();
    return {for (final r in rows) '${r.videoId}|${r.formatKey}'}
        .intersection(wanted);
  }

  // ── writes ───────────────────────────────────────────────────────────────

  @override
  Future<Result<DownloadTask>> transition(
    String id,
    TaskStatus to, {
    PauseReason? pauseReason,
    AppFailure? failure,
    DateTime? notBefore,
    String? outputPath,
    bool countAttempt = false,
    EventType? event,
    Map<String, Object?> eventArgs = const {},
  }) async {
    try {
      await _db.transaction(() async {
        final t = _db.downloadTasks;
        final row = await (_db.select(
          t,
        )..where((r) => r.id.equals(id))).getSingle();
        TaskStateMachine.ensure(row.status, to);
        final now = _clock.now();
        await (_db.update(t)..where((r) => r.id.equals(id))).write(
          DownloadTasksCompanion(
            status: Value(to),
            pauseReason: Value(
              to == TaskStatus.paused ? pauseReason ?? PauseReason.user : null,
            ),
            failureType: Value(to == TaskStatus.failed ? failure?.type : null),
            failureDebug: Value(
              to == TaskStatus.failed ? failure?.debug : null,
            ),
            notBefore: Value(notBefore),
            attempt: countAttempt
                ? Value(row.attempt + 1)
                : const Value.absent(),
            outputPath: outputPath != null
                ? Value(outputPath)
                : const Value.absent(),
            updatedAt: Value(now),
            completedAt: to == TaskStatus.completed
                ? Value(now)
                : const Value.absent(),
          ),
        );
        if (event != null) {
          await _insertEvent(
            DownloadEvent(taskId: id, type: event, at: now, args: eventArgs),
          );
        }
      });
      return Result.success((await task(id))!);
    } on Object catch (e, s) {
      return Result.failure(FailureMapper.map(e, s));
    }
  }

  @override
  Future<void> saveLeg(String taskId, TransferLeg leg) => _db
      .into(_db.taskLegs)
      .insertOnConflictUpdate(_toLegCompanion(taskId, leg));

  @override
  Future<void> replaceLegs(String taskId, List<TransferLeg> legs) =>
      _db.transaction(() async {
        await (_db.delete(
          _db.taskLegs,
        )..where((r) => r.taskId.equals(taskId))).go();
        for (final leg in legs) {
          await _db.into(_db.taskLegs).insert(_toLegCompanion(taskId, leg));
        }
      });

  @override
  Future<void> addEvent(DownloadEvent event) => _insertEvent(event);

  @override
  Future<int> clearFinished() => _db.transaction(() async {
    final t = _db.downloadTasks;
    final removed =
        await (_db.delete(t)..where(
              (r) => r.status.isIn([
                TaskStatus.completed.name,
                TaskStatus.cancelled.name,
              ]),
            ))
            .go();
    // A playlist group with nothing left in the queue goes too.
    await _db.customStatement(
      'DELETE FROM download_groups WHERE id NOT IN (SELECT DISTINCT group_id FROM download_tasks WHERE group_id IS NOT NULL)',
    );
    return removed;
  });

  // ── mapping ──────────────────────────────────────────────────────────────

  Future<void> _insertEvent(DownloadEvent e) => _db
      .into(_db.taskEvents)
      .insert(
        TaskEventsCompanion.insert(
          taskId: e.taskId,
          type: e.type,
          at: e.at,
          argsJson: Value(e.args.isEmpty ? null : jsonEncode(e.args)),
        ),
      );

  static TaskLegsCompanion _toLegCompanion(String taskId, TransferLeg leg) =>
      TaskLegsCompanion.insert(
        taskId: taskId,
        kind: leg.kind,
        itag: Value(leg.itag),
        ext: Value(leg.ext),
        totalBytes: Value(leg.totalBytes),
        doneBytes: Value(leg.doneBytes),
        tmpPath: leg.tmpPath,
        completed: Value(leg.completed),
      );

  static DownloadTask _toTask(DownloadTaskRow r, List<TaskLegRow> legs) =>
      DownloadTask(
        id: r.id,
        groupId: r.groupId,
        position: r.position,
        playlistIndex: r.playlistIndex,
        media: MediaInfo(
          videoId: r.videoId,
          url: r.sourceUrl,
          title: r.title,
          channel: r.channel,
          duration: r.durationMs == null
              ? null
              : Duration(milliseconds: r.durationMs!),
          thumbnailUrl: r.thumbUrl,
        ),
        format: FormatSelector.fromJson(
          jsonDecode(r.formatJson) as Map<String, Object?>,
        ),
        status: r.status,
        pauseReason: r.pauseReason,
        failure: r.failureType == null
            ? null
            : AppFailure(type: r.failureType!, debug: r.failureDebug),
        attempt: r.attempt,
        notBefore: r.notBefore,
        legs: [
          for (final l in legs)
            TransferLeg(
              kind: l.kind,
              tmpPath: l.tmpPath,
              doneBytes: l.doneBytes,
              totalBytes: l.totalBytes,
              itag: l.itag,
              ext: l.ext,
              completed: l.completed,
            ),
        ],
        outputPath: r.outputPath,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
        completedAt: r.completedAt,
      );

  static DownloadEvent _toEvent(TaskEventRow r) => DownloadEvent(
    taskId: r.taskId,
    type: r.type,
    at: r.at,
    args: r.argsJson == null
        ? const {}
        : jsonDecode(r.argsJson!) as Map<String, Object?>,
  );
}
