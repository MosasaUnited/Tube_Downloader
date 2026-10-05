/// Keeps a local copy of each finished video's thumbnail, so the library
/// still shows pictures offline (thumbnail URLs also expire).
abstract interface class ThumbnailStore {
  /// Saves [url] for [videoId] and returns the local path; null when it
  /// couldn't — best effort, a download never fails over its thumbnail.
  Future<String?> save(String videoId, String url);

  Future<void> delete(String path);
}

/// Tests, and platforms where nothing is cached.
class NoThumbnailStore implements ThumbnailStore {
  const NoThumbnailStore();

  @override
  Future<String?> save(String videoId, String url) async => null;

  @override
  Future<void> delete(String path) async {}
}
