import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/data/repos/library_repo_impl.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';

LibraryItem _item(
  String id,
  String title, {
  MediaKind kind = MediaKind.video,
  int bytes = 100,
  int day = 1,
}) => LibraryItem(
  id: id,
  videoId: 'vid$id',
  sourceUrl: 'https://www.youtube.com/watch?v=vid$id',
  title: title,
  channel: 'Channel',
  kind: kind,
  container: kind == MediaKind.video ? OutContainer.mp4 : OutContainer.mp3,
  path: '/downloads/$id',
  bytes: bytes,
  completedAt: DateTime(2026, 10, day),
);

void main() {
  late AppDatabase db;
  late LibraryRepoImpl repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = LibraryRepoImpl(db);
    await repo.add(_item('1', 'Tears of Steel', bytes: 300, day: 1));
    await repo.add(_item('2', 'محاضرة أحمد في البرمجة', day: 3));
    await repo.add(
      _item('3', 'Lo-fi Beats', kind: MediaKind.audio, bytes: 50, day: 2),
    );
  });
  tearDown(() => db.close());

  Future<List<String>> ids({
    String query = '',
    MediaKind? kind,
    LibrarySort sort = LibrarySort.newest,
  }) async => (await repo.watch(query: query, kind: kind, sort: sort).first)
      .map((i) => i.id)
      .toList();

  test('sorting', () async {
    expect(await ids(), ['2', '3', '1']);
    expect(await ids(sort: LibrarySort.oldest), ['1', '3', '2']);
    expect(await ids(sort: LibrarySort.size), ['1', '2', '3']);
  });

  test('search is case-insensitive and folds Arabic letter variants', () async {
    expect(await ids(query: 'TEARS'), ['1']);
    expect(await ids(query: 'احمد'), [
      '2',
    ], reason: 'أحمد is stored; the user typed احمد');
    expect(
      await ids(query: 'channel'),
      hasLength(3),
      reason: 'channel is searchable too',
    );
  });

  test('kind filter, removal and missing flags', () async {
    expect(await ids(kind: MediaKind.audio), ['3']);
    await repo.setMissing({'1'}, missing: true);
    expect((await repo.all()).firstWhere((i) => i.id == '1').missing, isTrue);
    await repo.remove({'1', '3'});
    expect(await ids(), ['2']);
  });
}
