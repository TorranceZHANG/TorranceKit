import XCTest

@testable import TorranceKit

final class AppPathsTests: XCTestCase {
  func testMigratesLegacyFilesWithoutDeletingTheSource() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("TorranceKitMigrationTests-\(UUID().uuidString)")
    let legacyDirectory = root.appendingPathComponent("PasteNook", isDirectory: true)
    let currentDirectory = root.appendingPathComponent("TorranceKit", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(
      at: legacyDirectory,
      withIntermediateDirectories: true
    )
    let config = Data(#"{"maxItems":88}"#.utf8)
    let history = Data(#"[{"text":"kept"}]"#.utf8)
    let legacyConfigURL = legacyDirectory.appendingPathComponent("config.json")
    let legacyHistoryURL = legacyDirectory.appendingPathComponent("history.json")
    try config.write(to: legacyConfigURL)
    try history.write(to: legacyHistoryURL)

    try AppPaths.migrateLegacyData(from: legacyDirectory, to: currentDirectory)

    XCTAssertEqual(
      try Data(contentsOf: currentDirectory.appendingPathComponent("config.json")),
      config
    )
    XCTAssertEqual(
      try Data(
        contentsOf:
          currentDirectory
          .appendingPathComponent("Clipboard", isDirectory: true)
          .appendingPathComponent("history.json")
      ),
      history
    )
    XCTAssertTrue(FileManager.default.fileExists(atPath: legacyConfigURL.path))
    XCTAssertTrue(FileManager.default.fileExists(atPath: legacyHistoryURL.path))
  }

  func testMigrationDoesNotOverwriteCurrentFiles() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("TorranceKitMigrationTests-\(UUID().uuidString)")
    let legacyDirectory = root.appendingPathComponent("PasteNook", isDirectory: true)
    let currentDirectory = root.appendingPathComponent("TorranceKit", isDirectory: true)
    let currentClipboardDirectory =
      currentDirectory
      .appendingPathComponent("Clipboard", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(at: legacyDirectory, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(
      at: currentClipboardDirectory,
      withIntermediateDirectories: true
    )
    let currentConfig = Data(#"{"maxItems":999}"#.utf8)
    let currentConfigURL = currentDirectory.appendingPathComponent("config.json")
    try Data(#"{"maxItems":1}"#.utf8).write(
      to: legacyDirectory.appendingPathComponent("config.json")
    )
    try currentConfig.write(to: currentConfigURL)

    try AppPaths.migrateLegacyData(from: legacyDirectory, to: currentDirectory)

    XCTAssertEqual(try Data(contentsOf: currentConfigURL), currentConfig)
  }
}
