import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

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
