import Flutter
import UIKit
import XCTest
import UserNotifications
@testable import Runner

class RunnerTests: XCTestCase {

  private func alert(phase: String = "focus", generation: Int64 = 3) -> PomaAlertRequest {
    PomaAlertRequest(runId: "persisted-session", generation: generation, notificationId: 7,
      phase: phase, elapsedDeadlineMicros: 1_500_000, maximumRemainingMicros: 1_000_000)
  }

  func testAlertUsesOneShotElapsedIntervalAndPersistedIdentity() throws {
    let request = try XCTUnwrap(alert().notification(elapsedNow: 1_250_000))
    let trigger = try XCTUnwrap(request.trigger as? UNTimeIntervalNotificationTrigger)
    XCTAssertEqual(trigger.timeInterval, 0.25, accuracy: 0.000001)
    XCTAssertFalse(trigger.repeats)
    XCTAssertEqual(request.identifier, "poma.timer.7")
    XCTAssertEqual(request.content.userInfo["pomaRunId"] as? String, "persisted-session")
    XCTAssertEqual(request.content.userInfo["pomaGeneration"] as? Int64, 3)
    XCTAssertEqual(request.content.body, "Open Poma when you’re ready.")
  }

  func testExpiredAlertIsNotReplayed() {
    XCTAssertNil(alert().notification(elapsedNow: 1_500_000))
    XCTAssertNil(alert().notification(elapsedNow: 9_000_000))
  }

  func testBreakWordingAndActionsDoNotStartAPhase() throws {
    for phase in ["shortBreak", "longBreak"] {
      let request = try XCTUnwrap(alert(phase: phase).notification(elapsedNow: 1_000_000))
      XCTAssertEqual(request.content.title, "Break complete")
      XCTAssertEqual(request.content.categoryIdentifier, PomaLocalAlerts.category.identifier)
    }
    let actions = PomaLocalAlerts.category.actions
    XCTAssertEqual(actions.map(\.identifier), ["open", "dismiss"])
    XCTAssertTrue(actions[0].options.contains(.foreground))
    XCTAssertFalse(actions[1].options.contains(.foreground))
  }

  func testStaleRunOrSegmentDoesNotMatch() {
    XCTAssertTrue(alert().matches(runId: "persisted-session", generation: 3))
    XCTAssertFalse(alert().matches(runId: "persisted-session", generation: 2))
    XCTAssertFalse(alert().matches(runId: "old-session", generation: 3))
  }

  func testResponseJournalSurvivesRecreationAndDeduplicatesTaps() throws {
    let suite = "poma-alert-test-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let journal = PomaAlertResponses(defaults: defaults)
    journal.append(runId: "run", generation: 1, action: "open")
    journal.append(runId: "run", generation: 1, action: "open")
    journal.append(runId: "run", generation: 1, action: "start")
    let restored = PomaAlertResponses(defaults: defaults)
    XCTAssertEqual(restored.values.count, 1)
    restored.acknowledge("action:run:1:open")
    XCTAssertTrue(journal.values.isEmpty)
  }

  func testConcurrentNativeResponsesDoNotOverwriteEachOther() throws {
    let suite = "poma-alert-test-" + UUID().uuidString
    let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let journal = PomaAlertResponses(defaults: defaults)
    DispatchQueue.concurrentPerform(iterations: 20) { index in
      journal.append(runId: "run-\(index)", generation: 1, action: "open")
    }
    XCTAssertEqual(journal.values.count, 20)
  }

  func testExclusionPreservesDatabaseAndSidecars() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("poma-backup-test-" + UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let contents = Data("Existing local data".utf8)
    let files = ["poma.db", "poma.db-wal", "poma.db-shm", "poma.db-journal"]
    for file in files {
      try contents.write(to: directory.appendingPathComponent(file))
    }
    try LocalBackupPolicy.exclude(directory: directory.path)
    try LocalBackupPolicy.exclude(directory: directory.path)
    XCTAssertEqual(
      try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup,
      true
    )
    for file in files {
      XCTAssertEqual(try Data(contentsOf: directory.appendingPathComponent(file)), contents)
    }
  }

  func testCannotExcludeTheContainerRootOrAnOutsideDirectory() {
    XCTAssertThrowsError(try LocalBackupPolicy.exclude(directory: NSHomeDirectory()))
    XCTAssertThrowsError(try LocalBackupPolicy.exclude(directory: "/"))
  }

  func testCreatesExcludedDirectoryBeforeTheDatabaseExists() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("poma-new-backup-test-" + UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try LocalBackupPolicy.exclude(directory: directory.path)
    XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
    XCTAssertEqual(
      try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup,
      true
    )
  }

}
