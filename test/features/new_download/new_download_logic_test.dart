import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_option.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_resolver.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/platform/clipboard_service.dart';
import 'package:tube_downloader/core/platform/incoming_links.dart';
import 'package:tube_downloader/core/platform/link_file_reader.dart';
import 'package:tube_downloader/features/new_download/domain/default_format_picker.dart';
import 'package:tube_downloader/features/new_download/domain/usecases/enqueue_downloads_use_case.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_state.dart';
import 'package:tube_downloader/features/new_download/logic/single_link_cubit/single_link_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/single_link_cubit/single_link_state.dart';

class _Resolver extends Mock implements MediaResolver {}

class _Settings extends Mock implements SettingsRepo {}

class _Clipboard extends Mock implements ClipboardService {}

class _Files extends Mock implements LinkFileReader {}

class _Queue extends Mock implements DownloadQueueService {}

class _Repo extends Mock implements DownloadRepo {}

class _Enqueue extends Mock implements EnqueueDownloadsUseCase {}

FormatOption _video(int h, {OutContainer c = OutContainer.mp4}) => FormatOption(
  kind: MediaKind.video,
  label: '${h}p',
  container: c,
  height: h,
  selector: FormatSelector(kind: MediaKind.video, container: c, maxHeight: h),
  estimatedBytes: h * 1000,
);

FormatOption _audio(OutContainer c, int kbps) => FormatOption(
  kind: MediaKind.audio,
  label: c.name.toUpperCase(),
  container: c,
  bitrateKbps: kbps,
  selector: FormatSelector(
    kind: MediaKind.audio,
    container: c,
    audioKbps: c == OutContainer.mp3 ? kbps : null,
  ),
);

final _options = [
  _video(2160, c: OutContainer.webm),
  _video(1080),
  _video(1080, c: OutContainer.webm),
  _video(720),
  _audio(OutContainer.m4a, 128),
  _audio(OutContainer.mp3, 320),
  _audio(OutContainer.mp3, 192),
];

const _media = MediaInfo(
  videoId: 'R6MlUcmOul8',
  url: 'https://www.youtube.com/watch?v=R6MlUcmOul8',
  title: 'Tears of Steel',
  channel: 'Blender',
);
const _link = ParsedLink.video(
  videoId: 'R6MlUcmOul8',
  url: 'https://www.youtube.com/watch?v=R6MlUcmOul8',
);

void main() {
  setUpAll(() {
    registerFallbackValue(_link);
    registerFallbackValue(<DownloadRequest>[]);
  });

  group('DefaultFormatPicker', () {
    test('video: best at or under the default height, MP4 before WebM', () {
      final pick = DefaultFormatPicker.pick(
        _options,
        MediaKind.video,
        const AppSettings(),
      );
      expect((pick!.height, pick.container), (1080, OutContainer.mp4));
      expect(
        DefaultFormatPicker.pick(
          _options,
          MediaKind.video,
          const AppSettings(defaultMaxHeight: 480),
        )!.height,
        720,
        reason: 'nothing that small → the smallest available',
      );
    });

    test('audio: MP3 at the default bitrate, else M4A', () {
      expect(
        DefaultFormatPicker.pick(
          _options,
          MediaKind.audio,
          const AppSettings(),
        )!.bitrateKbps,
        192,
      );
      expect(
        DefaultFormatPicker.pick(
          _options,
          MediaKind.audio,
          const AppSettings(audioKbps: 64),
        )!.container,
        OutContainer.m4a,
      );
    });
  });

  group('EnqueueDownloadsUseCase', () {
    test('skips what is already queued and counts it', () async {
      final queue = _Queue();
      final repo = _Repo();
      final fresh = DownloadRequest(
        media: _media.copyWith(videoId: 'fresh'),
        format: _video(1080).selector,
      );
      final dup = DownloadRequest(media: _media, format: _video(1080).selector);
      when(() => repo.existingKeys(any()))
          .thenAnswer((_) async => {'R6MlUcmOul8|${dup.format.key}'});
      when(() => queue.enqueue(any(), group: any(named: 'group')))
          .thenAnswer((_) async => const Result.success(['t1']));

      final result = await EnqueueDownloadsUseCase(queue, repo)([fresh, dup]);

      final summary = (result as Success<EnqueueSummary>).data;
      expect((summary.added, summary.skipped), (1, 1));
      final sent =
          verify(() => queue.enqueue(captureAny(), group: any(named: 'group')))
                  .captured
                  .single
              as List<DownloadRequest>;
      expect(sent.single.media.videoId, 'fresh');
    });
  });

  group('LinkInputCubit', () {
    late _Clipboard clipboard;
    late _Settings settings;
    late _Files files;
    late IncomingLinks incoming;
    setUp(() {
      incoming = IncomingLinks();
      clipboard = _Clipboard();
      settings = _Settings();
      files = _Files();
      when(() => settings.current).thenReturn(const AppSettings());
    });

    test(
      'a playlist link switches to Playlist, a video link back to Single',
      () {
        final cubit = LinkInputCubit(clipboard, settings, files, incoming)
          ..setText(
            'https://www.youtube.com/playlist?list=PLOU2XLYxmsIJ7ss3D9tXk2Tkk_1h2zNZb',
          );
        expect(cubit.state.mode, NewDownloadMode.playlist);
        cubit.setText('https://youtu.be/R6MlUcmOul8');
        expect(cubit.state.mode, NewDownloadMode.single);
      },
    );

    test('Multiple links never switches away', () {
      final cubit = LinkInputCubit(clipboard, settings, files, incoming)
        ..setMode(NewDownloadMode.multiple)
        ..setText('https://youtu.be/R6MlUcmOul8');
      expect(cubit.state.mode, NewDownloadMode.multiple);
    });

    test('one received link opens in its own tab and fetches', () {
      final cubit = LinkInputCubit(clipboard, settings, files, incoming)
        ..receive(
          'see https://www.youtube.com/playlist?list=PLOU2XLYxmsIJ7ss3D9tXk2Tkk_1h2zNZb',
        );
      expect(
        (cubit.state.mode, cubit.state.fetchToken, cubit.state.inboxToken),
        (NewDownloadMode.playlist, 1, 0),
      );
    });

    test('several received links (or any on Multiple) go to the batch', () {
      final cubit = LinkInputCubit(clipboard, settings, files, incoming)
        ..receive('https://youtu.be/R6MlUcmOul8\nhttps://youtu.be/aqz-KE-bpKQ');
      expect(
        (cubit.state.mode, cubit.state.inboxToken, cubit.state.fetchToken),
        (NewDownloadMode.multiple, 1, 0),
      );
      cubit.receive('https://youtu.be/R6MlUcmOul8');
      expect(cubit.state.inbox, 'https://youtu.be/R6MlUcmOul8');
      expect(cubit.state.inboxToken, 2, reason: 'already on Multiple');
    });

    test('dropped files are read and received', () async {
      when(() => files.readDropped(any()))
          .thenAnswer((_) async => 'https://youtu.be/R6MlUcmOul8');
      final cubit = LinkInputCubit(clipboard, settings, files, incoming);
      await cubit.receiveFiles(const []);
      expect(cubit.state.text, 'https://youtu.be/R6MlUcmOul8');
      expect(cubit.state.fetchToken, 1);
    });

    test('a shared link: waiting at open, then live', () async {
      incoming.add('https://youtu.be/R6MlUcmOul8');
      final cubit = LinkInputCubit(clipboard, settings, files, incoming)
        ..listenForShares();
      expect(cubit.state.text, 'https://youtu.be/R6MlUcmOul8');
      expect(cubit.state.fetchToken, 1);

      incoming.add('https://youtu.be/R6MlUcmOul8 https://youtu.be/aqz-KE-bpKQ');
      await pumpEventQueue();
      expect(cubit.state.mode, NewDownloadMode.multiple, reason: 'several');
      expect(incoming.takePending(), isNull, reason: 'delivered live');
      await cubit.close();
    });

    test('fetch only fires for a link the current tab can take', () {
      final cubit = LinkInputCubit(clipboard, settings, files, incoming)
        ..setText('nonsense');
      cubit.fetch();
      expect(cubit.state.fetchToken, 0);
      cubit
        ..setText('https://youtu.be/R6MlUcmOul8')
        ..fetch();
      expect(cubit.state.fetchToken, 1);
    });

    test('clipboard: suggests a supported link once, not what is already typed, not when disabled', () async {
      when(() => clipboard.readText())
          .thenAnswer((_) async => 'https://youtu.be/R6MlUcmOul8');
      final cubit = LinkInputCubit(clipboard, settings, files, incoming);
      await cubit.checkClipboard();
      expect(cubit.state.clipboardSuggestion, 'https://youtu.be/R6MlUcmOul8');

      cubit.useSuggestion();
      expect(
        (
          cubit.state.text,
          cubit.state.clipboardSuggestion,
          cubit.state.fetchToken,
        ),
        ('https://youtu.be/R6MlUcmOul8', null, 1),
      );
      await cubit.checkClipboard();
      expect(
        cubit.state.clipboardSuggestion,
        isNull,
        reason: 'already in the field',
      );

      when(() => clipboard.readText()).thenAnswer((_) async => 'hello');
      await cubit.checkClipboard();
      expect(cubit.state.clipboardSuggestion, isNull, reason: 'not a link');

      when(() => settings.current)
          .thenReturn(const AppSettings(clipboardWatch: false));
      when(() => clipboard.readText())
          .thenAnswer((_) async => 'https://youtu.be/aqz-KE-bpKQ');
      await cubit.checkClipboard();
      expect(
        cubit.state.clipboardSuggestion,
        isNull,
        reason: 'disabled in Settings',
      );
    });
  });

  group('SingleLinkCubit', () {
    late _Resolver resolver;
    late _Enqueue enqueue;
    late _Settings settings;
    setUp(() {
      resolver = _Resolver();
      enqueue = _Enqueue();
      settings = _Settings();
      when(() => settings.current).thenReturn(const AppSettings());
    });

    blocTest<SingleLinkCubit, SingleLinkState>(
      'fetch: loading → ready with the default format preselected',
      build: () {
        when(() => resolver.resolve(any())).thenAnswer(
          (_) async => const Result.success(ResolvedLink.single(_media)),
        );
        when(() => resolver.formats(any()))
            .thenAnswer((_) async => Result.success(_options));
        return SingleLinkCubit(resolver, enqueue, settings);
      },
      act: (c) => c.fetch(_link),
      expect: () => [
        const SingleLinkState.loading(),
        isA<SingleReady>()
            .having((s) => s.selected.height, 'height', 1080)
            .having((s) => s.kind, 'kind', MediaKind.video),
      ],
    );

    blocTest<SingleLinkCubit, SingleLinkState>(
      'a live stream is refused up front',
      build: () {
        when(() => resolver.resolve(any())).thenAnswer(
          (_) async => Result.success(
            ResolvedLink.single(_media.copyWith(isLive: true)),
          ),
        );
        return SingleLinkCubit(resolver, enqueue, settings);
      },
      act: (c) => c.fetch(_link),
      expect: () => [
        const SingleLinkState.loading(),
        const SingleLinkState.failure(
          AppFailure(type: FailureType.liveNotSupported),
        ),
      ],
      verify: (_) => verifyNever(() => resolver.formats(any())),
    );

    blocTest<SingleLinkCubit, SingleLinkState>(
      'a resolve failure is carried as is',
      build: () {
        when(() => resolver.resolve(any())).thenAnswer(
          (_) async =>
              const Result.failure(AppFailure(type: FailureType.privateVideo)),
        );
        return SingleLinkCubit(resolver, enqueue, settings);
      },
      act: (c) => c.fetch(_link),
      expect: () => [
        const SingleLinkState.loading(),
        const SingleLinkState.failure(
          AppFailure(type: FailureType.privateVideo),
        ),
      ],
    );

    test(
      'switching to audio picks the default MP3; download sends the selector',
      () async {
        when(() => resolver.resolve(any())).thenAnswer(
          (_) async => const Result.success(ResolvedLink.single(_media)),
        );
        when(() => resolver.formats(any()))
            .thenAnswer((_) async => Result.success(_options));
        when(() => enqueue(any())).thenAnswer(
          (_) async =>
              const Result.success(EnqueueSummary(added: 1, skipped: 0)),
        );
        final cubit = SingleLinkCubit(resolver, enqueue, settings);
        await cubit.fetch(_link);

        cubit.selectKind(MediaKind.audio);
        expect((cubit.state as SingleReady).selected.bitrateKbps, 192);

        final result = await cubit.download();
        expect(result, isA<Success<EnqueueSummary>>());
        final sent =
            verify(() => enqueue(captureAny())).captured.single
                as List<DownloadRequest>;
        expect(
          sent.single.format,
          const FormatSelector(
            kind: MediaKind.audio,
            container: OutContainer.mp3,
            audioKbps: 192,
          ),
        );
        expect((cubit.state as SingleReady).enqueuing, isFalse);
        await cubit.close();
      },
    );

    test('closing mid-fetch is safe (state-safety)', () async {
      final pending = Completer<Result<ResolvedLink>>();
      when(() => resolver.resolve(any())).thenAnswer((_) => pending.future);
      final cubit = SingleLinkCubit(resolver, enqueue, settings);
      final fetching = cubit.fetch(_link);
      await cubit.close();
      pending.complete(const Result.success(ResolvedLink.single(_media)));
      await expectLater(fetching, completes);
    });
  });
}
