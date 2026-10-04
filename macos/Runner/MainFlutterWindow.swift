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
}
