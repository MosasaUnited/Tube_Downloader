import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';

part 'library_item.freezed.dart';

/// A finished file in the library.
@freezed
abstract class LibraryItem with _$LibraryItem {
  const factory LibraryItem({
    required String id,
    required String videoId,
    required String sourceUrl,
    required String title,
    required String channel,
    required MediaKind kind,
    required OutContainer container,
    required String path,
    required int bytes,
    required DateTime completedAt,
    String? taskId,
    int? height,
    Duration? duration,
    String? thumbPath,
    @Default(false) bool missing,
  }) = _LibraryItem;
}

enum LibrarySort { newest, oldest, name, size }
