import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/link/link_parser.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/platform/clipboard_service.dart';
import 'package:tube_downloader/core/platform/incoming_links.dart';
import 'package:tube_downloader/core/platform/link_file_reader.dart';
import 'package:tube_downloader/features/new_download/domain/link_batch_analyzer.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_state.dart';

class LinkInputCubit extends Cubit<LinkInputState> {
  LinkInputCubit(this._clipboard, this._settings, this._files, this._incoming)
    : super(const LinkInputState());

  final ClipboardService _clipboard;
  final SettingsRepo _settings;
  final LinkFileReader _files;
  final IncomingLinks _incoming;
  StreamSubscription<String>? _incomingSub;

  /// Links shared into the app (Android's share sheet): the one waiting when
  /// the screen opens, then each new one.
  void listenForShares() {
    final pending = _incoming.takePending();
    if (pending != null) receive(pending);
    _incomingSub ??= _incoming.stream.listen((text) {
      if (!isClosed) receive(text);
    });
  }

  void setMode(NewDownloadMode mode) => emit(state.copyWith(mode: mode));

  /// A playlist link moves the user to the Playlist tab (and a video link
  /// back to Single) — never out of Multiple, which takes any text.
  void setText(String text) {
    final parsed = LinkParser.parse(text);
    var mode = state.mode;
    if (mode != NewDownloadMode.multiple) {
      if (parsed is ParsedPlaylist) mode = NewDownloadMode.playlist;
      if (parsed is ParsedVideo) mode = NewDownloadMode.single;
    }
    emit(state.copyWith(text: text, parsed: parsed, mode: mode));
  }

  /// Asks the active tab to fetch (see [LinkInputState.fetchToken]).
  void fetch() {
    if (state.canFetch) emit(state.copyWith(fetchToken: state.fetchToken + 1));
  }

  /// Opens one link in the tab that fits it (Single or Playlist) and fetches.
  void open(String link) {
    final mode = LinkParser.parse(link) is ParsedPlaylist
        ? NewDownloadMode.playlist
        : NewDownloadMode.single;
    emit(state.copyWith(mode: mode));
    setText(link);
    fetch();
  }

  /// Links from outside the URL bar (a drop, the clipboard banner). A single
  /// link opens in its tab; several — or any while on Multiple — go to the
  /// Multiple tab's box.
  void receive(String text) {
    if (text.trim().isEmpty) return;
    final links = LinkBatchAnalyzer.analyze(text)
        .where((e) => e.link is! ParsedUnsupported)
        .toList();
    if (state.mode != NewDownloadMode.multiple && links.length == 1) {
      return open(links.single.input);
    }
    emit(
      state.copyWith(
        mode: NewDownloadMode.multiple,
        inbox: text,
        inboxToken: state.inboxToken + 1,
      ),
    );
  }

  /// Files dropped on the window (.txt / .webloc / .url).
  Future<void> receiveFiles(List<XFile> files) async {
    final text = await _files.readDropped(files);
    if (isClosed) return;
    receive(text);
  }

  Future<void> paste() async {
    final text = await _clipboard.readText();
    if (isClosed || text == null || text.trim().isEmpty) return;
    setText(text.trim());
    fetch();
  }

  /// Offers a supported link found on the clipboard (Settings › Clipboard
  /// Auto-Detection). Called when the screen opens and when the app resumes.
  Future<void> checkClipboard() async {
    if (!_settings.current.clipboardWatch) return;
    final text = (await _clipboard.readText())?.trim();
    if (isClosed ||
        text == null ||
        text == state.text ||
        text == state.clipboardSuggestion) {
      return;
    }
    if (LinkParser.parse(text) is ParsedUnsupported) return;
    emit(state.copyWith(clipboardSuggestion: text));
  }

  void useSuggestion() {
    final suggestion = state.clipboardSuggestion;
    if (suggestion == null) return;
    emit(state.copyWith(clipboardSuggestion: null));
    receive(suggestion);
  }

  void dismissSuggestion() => emit(state.copyWith(clipboardSuggestion: null));

  @override
  Future<void> close() async {
    await _incomingSub?.cancel();
    return super.close();
  }
}
