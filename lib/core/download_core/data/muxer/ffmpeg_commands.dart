/// FFmpeg argument lists, kept pure so they are unit-tested without the
/// plugin. Inputs are file paths; output containers follow the extension.
abstract final class FfmpegCommands {
  /// Separate video + audio streams into one file WITHOUT re-encoding — the
  /// merge is near-instant (< 1 s for ~250 MB, docs/spike/phase0.md).
  static List<String> merge({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) => [
    '-y', '-hide_banner', '-nostdin', //
    '-i', videoPath,
    '-i', audioPath,
    '-map', '0:v:0',
    '-map', '1:a:0',
    '-c', 'copy',
    ..._faststart(outputPath),
    outputPath,
  ];

  /// Audio → MP3 with lame at [kbps] (included in the LGPL "audio" build).
  static List<String> toMp3({
    required String audioPath,
    required String outputPath,
    required int kbps,
  }) => [
    '-y', '-hide_banner', '-nostdin', //
    '-i', audioPath,
    '-vn',
    '-c:a', 'libmp3lame',
    '-b:a', '${kbps}k',
    outputPath,
  ];

  /// MP4-family outputs get their index moved to the front so players can
  /// start before reading the whole file.
  static List<String> _faststart(String outputPath) {
    final lower = outputPath.toLowerCase();
    return lower.endsWith('.mp4') || lower.endsWith('.m4a')
        ? const ['-movflags', '+faststart']
        : const [];
  }

  /// FFmpeg reports how much OUTPUT time it has written; against the known
  /// duration that is the progress fraction (clamped; null when unknown).
  static double? progressFraction(int processedMs, Duration? duration) {
    if (duration == null || duration.inMilliseconds <= 0) return null;
    return (processedMs / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}
