import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';

part 'stream_target.freezed.dart';

/// A resolved, fetchable stream for one leg — short-lived (the URL expires
/// and is tied to the IP address), so it is resolved right before transfer.
@freezed
abstract class StreamTarget with _$StreamTarget {
  const factory StreamTarget({
    required LegKind leg,
    required int itag,
    required Uri url,
    required int totalBytes,

    /// File extension of the raw stream ("mp4", "webm", "m4a").
    required String ext,
    @Default(<String, String>{}) Map<String, String> headers,
    DateTime? expiresAt,

    /// The server wants the byte range in the query (`&range=a-b`) rather than
    /// a `Range` header (non-Android YouTube clients).
    @Default(true) bool rangeInQuery,
  }) = _StreamTarget;
}
