import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// Held while downloads run, so macOS App Nap does not throttle the app's
  /// timers, network and FFmpeg work when its window is in the background.
  private var downloadActivity: NSObjectProtocol?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerActivityChannel(messenger: flutterViewController.engine.binaryMessenger)
    registerStorageChannel(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  /// `com.tubedownloader.app/activity`: "begin" / "end" (idempotent).
  /// User-initiated activity that still allows idle system sleep.
  private func registerActivityChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.tubedownloader.app/activity", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return result(nil) }
      switch call.method {
      case "begin":
        if self.downloadActivity == nil {
          let reason = (call.arguments as? [String: Any])?["reason"] as? String ?? "Downloading"
          self.downloadActivity = ProcessInfo.processInfo.beginActivity(
            options: .userInitiatedAllowingIdleSystemSleep, reason: reason)
        }
        result(nil)
      case "end":
        if let activity = self.downloadActivity {
          ProcessInfo.processInfo.endActivity(activity)
          self.downloadActivity = nil
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// `com.tubedownloader.app/storage`: "space" {path} → {free, total} bytes of
  /// the volume holding `path` (free = what macOS counts as available for
  /// important data, purgeable space included), or nil when unreadable.
  private func registerStorageChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.tubedownloader.app/storage", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "space" else { return result(FlutterMethodNotImplemented) }
      guard let path = (call.arguments as? [String: Any])?["path"] as? String else {
        return result(FlutterError(code: "args", message: "path missing", details: nil))
      }
      let keys: Set<URLResourceKey> = [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey]
      guard let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: keys),
            let free = values.volumeAvailableCapacityForImportantUsage,
            let total = values.volumeTotalCapacity
      else { return result(nil) }
      result(["free": free, "total": Int64(total)])
    }
  }
}
