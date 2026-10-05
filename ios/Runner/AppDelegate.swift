import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Download banners also show while the app is open (flutter_local_notifications).
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "TubeStorageSpace") {
      registerStorageChannel(messenger: registrar.messenger())
    }
  }

  /// `com.tubedownloader.app/storage`: "space" {path} → {free, total} bytes of
  /// the volume holding `path` (free = available for important data, the
  /// figure iOS itself shows), or nil when unreadable.
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
