/// Enumerations shared by the download core. Stored as text in drift, so the
/// NAMES are part of the database format: never rename a value — add a new one
/// and migrate.
library;

/// A task's lifecycle (see TaskStateMachine for the legal transitions).
enum TaskStatus {
  queued,
  resolving,
  downloadingVideo,
  downloadingAudio,
  merging,
  converting,
  completed,
  paused,
  failed,
  cancelled;

  bool get isActive => switch (this) {
    resolving ||
    downloadingVideo ||
    downloadingAudio ||
    merging ||
    converting => true,
    _ => false,
  };

  bool get isFinal => this == completed || this == cancelled;
}

/// Why a task is paused. Everything except [user] resumes on its own.
enum PauseReason { user, waitingForWifi, offline }

/// One stream a task downloads: separate video + audio legs, or one muxed leg.
enum LegKind { video, audio, muxed }

/// The task timeline shown in the details pane (args only — never English text).
enum EventType {
  requested,
  resolved,
  videoStarted,
  videoDone,
  audioStarted,
  audioDone,
  mergeStarted,
  convertStarted,
  reResolved,
  paused,
  resumed,
  retried,
  completed,
  failed,
  cancelled,
}

/// What the user asked for.
enum MediaKind { video, audio }

/// The container of the finished file.
enum OutContainer { mp4, webm, m4a, mp3 }
