import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';

part 'link_input_state.freezed.dart';

enum NewDownloadMode { single, playlist, multiple }

/// The shared URL bar: what is typed, what it parses to, which tab is shown,
/// and a link found on the clipboard.
@freezed
abstract class LinkInputState with _$LinkInputState {
  const factory LinkInputState({
    @Default(NewDownloadMode.single) NewDownloadMode mode,
    @Default('') String text,
    ParsedLink? parsed,
    String? clipboardSuggestion,

    /// Bumped by "Fetch"; the active tab's view listens and fetches.
    @Default(0) int fetchToken,

    /// Links for the Multiple tab from outside it (a drop, the clipboard
    /// banner); [inboxToken] is bumped with each delivery.
    @Default('') String inbox,
    @Default(0) int inboxToken,
  }) = _LinkInputState;

  const LinkInputState._();

  bool get canFetch => switch (parsed) {
    ParsedVideo() => mode == NewDownloadMode.single,
    ParsedPlaylist() => mode == NewDownloadMode.playlist,
    _ => false,
  };
}
