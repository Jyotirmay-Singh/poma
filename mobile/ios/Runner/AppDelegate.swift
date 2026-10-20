import Flutter
import Darwin
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let clockChannel = FlutterMethodChannel(
      name: "dev.poma.poma/timer_clock",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    clockChannel.setMethodCallHandler { call, result in
      guard call.method == "sample" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // CLOCK_MONOTONIC_RAW includes system sleep and is unaffected by wall time.
      result([
        "utcMicros": Int64(Date().timeIntervalSince1970 * 1_000_000),
        "elapsedMicros": Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1_000)
      ])
    }

    let channel = FlutterMethodChannel(
      name: "dev.poma.poma/local_storage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
        let directory = arguments["directory"] as? String, !directory.isEmpty
      else {
        result(FlutterError(
          code: "invalid_directory", message: "A local directory is required.", details: nil
        ))
        return
      }
      do {
        try LocalBackupPolicy.exclude(directory: directory)
        result(nil)
      } catch {
        result(FlutterError(
          code: "backup_exclusion_failed",
          message: "Local storage backup exclusions could not be applied.",
          details: nil
        ))
      }
    }
  }
}

enum LocalBackupPolicy {
  static func exclude(directory: String) throws {
    let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
      .standardizedFileURL.resolvingSymlinksInPath()
    var url = URL(fileURLWithPath: directory, isDirectory: true)
      .standardizedFileURL.resolvingSymlinksInPath()
    guard url.path.hasPrefix(home.path + "/") else {
      throw NSError(domain: "dev.poma.poma.local_storage", code: 1)
    }
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    var values = URLResourceValues()
    values.isExcludedFromBackup = true
    try url.setResourceValues(values)
    guard try url.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true else {
      throw NSError(domain: "dev.poma.poma.local_storage", code: 2)
    }
  }
}
