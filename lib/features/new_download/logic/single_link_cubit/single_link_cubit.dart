import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_option.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_resolver.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/features/new_download/domain/default_format_picker.dart';
import 'package:tube_downloader/features/new_download/domain/usecases/enqueue_downloads_use_case.dart';
import 'package:tube_downloader/features/new_download/logic/single_link_cubit/single_link_state.dart';

/// One video: resolve → formats → the user's choice → enqueue.
class SingleLinkCubit extends Cubit<SingleLinkState> {
  SingleLinkCubit(this._resolver, this._enqueue, this._settings)
    : super(const SingleLinkState.idle());

  final MediaResolver _resolver;
  final EnqueueDownloadsUseCase _enqueue;
  final SettingsRepo _settings;

  Future<void> fetch(ParsedLink link) async {
    emit(const SingleLinkState.loading());
    final resolved = await _resolver.resolve(link);
    if (isClosed) return;
    final MediaInfo media;
    switch (resolved) {
      case Failure(:final failure):
        return emit(SingleLinkState.failure(failure));
      case Success(:final data):
        if (data is! ResolvedSingle) {
          return emit(
            const SingleLinkState.failure(
              AppFailure(type: FailureType.unsupportedLink),
            ),
          );
        }
        media = data.media;
    }
    // Live streams can't be downloaded: say so now, not after queueing.
    if (media.isLive) {
      return emit(
        const SingleLinkState.failure(
          AppFailure(type: FailureType.liveNotSupported),
        ),
      );
    }

    final formats = await _resolver.formats(media.videoId);
    if (isClosed) return;
    switch (formats) {
      case Failure(:final failure):
        emit(SingleLinkState.failure(failure));
      case Success(:final data):
        final settings = _settings.current;
        final selected =
            DefaultFormatPicker.pick(data, settings.defaultKind, settings) ??
            DefaultFormatPicker.pick(data, MediaKind.video, settings)!;
        emit(
          SingleLinkState.ready(
            media: media,
            options: data,
            kind: selected.kind,
            selected: selected,
            recommended: selected,
            saveDirectory: settings.saveDirectory,
          ),
        );
    }
  }

  void selectKind(MediaKind kind) {
    final s = state;
    if (s is! SingleReady || s.kind == kind) return;
    final selected = DefaultFormatPicker.pick(
      s.options,
      kind,
      _settings.current,
    );
    if (selected != null) {
      emit(s.copyWith(kind: kind, selected: selected, recommended: selected));
    }
  }

  void select(FormatOption option) {
    final s = state;
    if (s is SingleReady) emit(s.copyWith(kind: option.kind, selected: option));
  }

  /// Returns the result so the screen can confirm ("Download started") or
  /// report the failure next to the button.
  Future<Result<EnqueueSummary>?> download() async {
    final s = state;
    if (s is! SingleReady || s.enqueuing) return null;
    emit(s.copyWith(enqueuing: true));
    final result = await _enqueue([
      DownloadRequest(media: s.media, format: s.selected.selector),
    ]);
    if (isClosed) return result;
    emit(s.copyWith(enqueuing: false));
    return result;
  }

  void reset() => emit(const SingleLinkState.idle());
}
