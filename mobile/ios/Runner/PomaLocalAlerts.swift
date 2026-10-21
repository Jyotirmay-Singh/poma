import Flutter
import Foundation
import Darwin
import SQLite3
import UserNotifications
import UIKit

struct PomaAlertRequest: Decodable {
  let runId: String
  let generation: Int64
  let notificationId: Int
  let phase: String
  let elapsedDeadlineMicros: Int64
  let maximumRemainingMicros: Int64

  var identifier: String { "poma.timer.\(notificationId)" }
  func matches(runId: String, generation: Int64) -> Bool {
    !runId.isEmpty && generation > 0 && self.runId == runId && self.generation == generation
  }
  func notification(elapsedNow: Int64) -> UNNotificationRequest? {
    let remaining = min(maximumRemainingMicros, elapsedDeadlineMicros - elapsedNow)
    guard remaining > 0, !runId.isEmpty, generation > 0, notificationId > 0 else { return nil }
    let content = UNMutableNotificationContent()
    content.title = phase == "focus"
      ? NSLocalizedString("alert_focus_complete", value: "Focus complete", comment: "Focus completion notification")
      : NSLocalizedString("alert_break_complete", value: "Break complete", comment: "Break completion notification")
    content.body = NSLocalizedString("alert_body", value: "Open Poma when you’re ready.", comment: "Notification body")
    content.sound = .default
    content.categoryIdentifier = PomaLocalAlerts.category.identifier
    content.userInfo = ["pomaRunId": runId, "pomaGeneration": generation]
    return UNNotificationRequest(identifier: identifier, content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: Double(remaining) / 1_000_000, repeats: false))
  }
}

private struct PomaAlertState: Decodable {
  let enabled: Bool
  let current: PomaAlertRequest?
  let previous: PomaAlertRequest?
  let retiredIds: [Int]
}

/// A native journal lets Dismiss finish without starting a headless Dart owner.
final class PomaAlertResponses {
  private let defaults: UserDefaults
  private let lock = NSLock()
  private let key = "poma.alert.responses"
  init(defaults: UserDefaults = .standard) { self.defaults = defaults }
  var values: [[String: Any]] {
    lock.lock(); defer { lock.unlock() }
    return Array((defaults.dictionary(forKey: key) as? [String: [String: Any]] ?? [:]).values)
  }
  func append(runId: String, generation: Int64, action: String) {
    guard !runId.isEmpty, generation > 0, ["open", "dismiss"].contains(action) else { return }
    lock.lock(); defer { lock.unlock() }
    var queue = defaults.dictionary(forKey: key) as? [String: [String: Any]] ?? [:]
    queue["action:\(runId):\(generation):\(action)"] = ["runId": runId, "generation": generation, "action": action]
    defaults.set(queue, forKey: key)
  }
  func acknowledge(_ receipt: String) {
    lock.lock(); defer { lock.unlock() }
    var queue = defaults.dictionary(forKey: key) as? [String: [String: Any]] ?? [:]
    queue.removeValue(forKey: receipt)
    defaults.set(queue, forKey: key)
  }
  func clear() {
    lock.lock(); defer { lock.unlock() }
    defaults.removeObject(forKey: key)
  }
}

final class PomaLocalAlerts {
  static let shared = PomaLocalAlerts()
  static let category = UNNotificationCategory(identifier: "poma_completion", actions: [
    UNNotificationAction(identifier: "open", title: NSLocalizedString("alert_open", value: "Open timer", comment: "Open timer action"), options: [.foreground]),
    UNNotificationAction(identifier: "dismiss", title: NSLocalizedString("alert_dismiss", value: "Dismiss", comment: "Dismiss notification action"), options: [])
  ], intentIdentifiers: [], options: [.customDismissAction])
  private var channel: FlutterMethodChannel?
  private let center = UNUserNotificationCenter.current()
  private let journal = PomaAlertResponses()
  private var timeObservers: [NSObjectProtocol] = []

  static func owns(_ identifier: String) -> Bool { identifier.hasPrefix("poma.timer.") }

  static func acceptsResponse(current: PomaAlertRequest?, previous: PomaAlertRequest?,
    runId: String, generation: Int64) -> Bool {
    if let current, current.matches(runId: runId, generation: generation) { return true }
    if let previous, previous.matches(runId: runId, generation: generation) { return true }
    return false
  }

  static func canRemoveDelivered(current: PomaAlertRequest?, generation: Int64) -> Bool {
    guard let current else { return true }
    return current.generation == generation
  }

  func attach(messenger: FlutterBinaryMessenger) {
    let bridge = FlutterMethodChannel(name: "dev.poma.poma/local_alerts", binaryMessenger: messenger)
    channel = bridge
    bridge.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      let arguments = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "configure":
        guard let path = arguments["databasePath"] as? String,
          URL(fileURLWithPath: path).standardizedFileURL.resolvingSymlinksInPath().path
            .hasPrefix(URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL.resolvingSymlinksInPath().path + "/") else {
          result(FlutterError(code: "invalid_database", message: "An app database is required", details: nil)); return
        }
        UserDefaults.standard.set(path, forKey: "poma.alert.database")
        self.center.setNotificationCategories([Self.category])
        if self.timeObservers.isEmpty {
          for name in [UIApplication.significantTimeChangeNotification, NSNotification.Name.NSSystemTimeZoneDidChange] {
            self.timeObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
              self?.channel?.invokeMethod("changed", arguments: nil)
            })
          }
        }
        result(nil)
      case "synchronize":
        guard let json = arguments["state"] as? String, let data = json.data(using: .utf8),
          let state = try? JSONDecoder().decode(PomaAlertState.self, from: data) else {
          result(FlutterError(code: "invalid_alert", message: "Saved alert is invalid", details: nil)); return
        }
        self.synchronize(state, permitted: arguments["permitted"] as? Bool == true, result: result)
      case "responses": result(self.journal.values)
      case "clearForReset":
        guard let saved = self.committedState(), saved.current == nil else {
          result(FlutterError(code: "reset_not_saved", message: "Data reset must be saved first", details: nil)); return
        }
        self.center.getPendingNotificationRequests { requests in
          self.center.removePendingNotificationRequests(withIdentifiers: requests.filter { Self.owns($0.identifier) }.map(\.identifier))
          self.center.getDeliveredNotifications { delivered in
            self.center.removeDeliveredNotifications(withIdentifiers: delivered.filter { Self.owns($0.request.identifier) }.map { $0.request.identifier })
            self.journal.clear()
            DispatchQueue.main.async { result(nil) }
          }
        }
      case "acknowledgeResponse":
        if let key = arguments["key"] as? String { self.journal.acknowledge(key) }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  // Receivers/responses must not open a new empty database or run domain logic.
  private func committedState() -> PomaAlertState? {
    guard let path = UserDefaults.standard.string(forKey: "poma.alert.database") else { return nil }
    var database: OpaquePointer?
    guard sqlite3_open_v2(path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
      if database != nil { sqlite3_close(database) }; return nil
    }
    defer { sqlite3_close(database) }
    var statement: OpaquePointer?
    guard sqlite3_prepare_v2(database, "SELECT value FROM notification_state WHERE id=1", -1, &statement, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(statement) }
    guard sqlite3_step(statement) == SQLITE_ROW, let bytes = sqlite3_column_text(statement, 0) else { return nil }
    return try? JSONDecoder().decode(PomaAlertState.self, from: Data(String(cString: bytes).utf8))
  }

  private func synchronize(_ state: PomaAlertState, permitted: Bool, result: @escaping FlutterResult) {
    center.getNotificationSettings { [weak self] settings in
      guard let self else { return }
      self.center.getPendingNotificationRequests { requests in
        // All operations enter via Dart's single command queue. Wait for the
        // add completion before acknowledging; repeated identifiers replace.
        let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        let allowed = permitted && authorized
        let desired = state.enabled && allowed ? state.current : nil
        let obsolete = requests.filter { request in
          guard Self.owns(request.identifier) else { return false }
          return request.identifier != desired?.identifier ||
            (request.content.userInfo["pomaGeneration"] as? NSNumber)?.int64Value != desired?.generation
        }.map(\.identifier)
        self.center.removePendingNotificationRequests(withIdentifiers: obsolete)
        var removed = state.retiredIds.map { "poma.timer.\($0)" }
        if let previous = state.previous, previous.identifier != desired?.identifier { removed.append(previous.identifier) }
        if !allowed, let current = state.current { removed.append(current.identifier) }
        self.center.removeDeliveredNotifications(withIdentifiers: removed)
        let finish: (String) -> Void = { value in DispatchQueue.main.async { result(value) } }
        guard state.enabled else { finish("disabled"); return }
        guard allowed else { finish("denied"); return }
        guard let desired else { finish("ready"); return }
        guard let committed = self.committedState()?.current,
          committed.matches(runId: desired.runId, generation: desired.generation) else {
          DispatchQueue.main.async { result(FlutterError(code: "uncommitted_alert", message: "Alert is not durably saved", details: nil)) }; return
        }
        let elapsedNow = Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) / 1_000)
        guard let notification = desired.notification(elapsedNow: elapsedNow) else {
          self.center.removePendingNotificationRequests(withIdentifiers: [desired.identifier])
          finish("ready"); return
        }
        if requests.contains(where: { $0.identifier == desired.identifier &&
            ($0.content.userInfo["pomaGeneration"] as? NSNumber)?.int64Value == desired.generation }) {
          finish("ready"); return
        }
        self.center.add(notification) { error in
          DispatchQueue.main.async {
            if error != nil { result(FlutterError(code: "schedule_failed", message: "Completion alert could not be registered", details: nil)) }
            else { result("ready") }
          }
        }
      }
    }
  }

  func shouldPresent(_ notification: UNNotification) -> Bool {
    let info = notification.request.content.userInfo
    guard let run = info["pomaRunId"] as? String, let generation = info["pomaGeneration"] as? NSNumber else { return false }
    return committedState()?.current?.matches(runId: run, generation: generation.int64Value) == true
  }

  func handle(_ response: UNNotificationResponse) {
    let info = response.notification.request.content.userInfo
    guard let run = info["pomaRunId"] as? String,
      let generation = info["pomaGeneration"] as? NSNumber,
      let state = committedState() else { return }
    // Explicit request values avoid a Swift 6.3.3 release-optimizer ownership
    // crash in chained optional projections of this decoded state.
    guard Self.acceptsResponse(current: state.current, previous: state.previous,
      runId: run, generation: generation.int64Value) else { return }
    let action: String
    switch response.actionIdentifier {
    case "open", UNNotificationDefaultActionIdentifier: action = "open"
    case "dismiss", UNNotificationDismissActionIdentifier: action = "dismiss"
    default: return
    }
    journal.append(runId: run, generation: generation.int64Value, action: action)
    // A stale dismissal cannot cancel a resumed segment with the same OS ID.
    if action == "dismiss", Self.canRemoveDelivered(current: state.current, generation: generation.int64Value) {
      center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
    }
    DispatchQueue.main.async { self.channel?.invokeMethod("changed", arguments: nil) }
  }
}
