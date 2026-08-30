import Foundation

@main
enum CoreTestRunner {
  @MainActor
  static func main() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("TorranceKitCoreTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }

    try testDeduplication(in: directory)
    try testCountRetention(in: directory)
    try testTimeRetention(in: directory)
    try testUnlimitedRetention(in: directory)
    try testPersistence(in: directory)
    try testPrivateFilePermissions(in: directory)
    try testLegacyDataMigration(in: directory)
    try testConfigurationDefaults()
    try testConfigurationValidation()
    print("TorranceKit core tests passed")
  }

  @MainActor
  private static func testDeduplication(in directory: URL) throws {
    let history = makeHistory(in: directory, name: "dedupe")
    history.add(text: "first")
    history.add(text: "second")
    history.add(text: "first")
    try expect(history.items.map(\.text) == ["first", "second"], "dedupe order")
    try expect(history.items.first?.copyCount == 2, "dedupe counter")
  }

  @MainActor
  private static func testCountRetention(in directory: URL) throws {
    let history = ClipboardHistory(
      maxItems: 2,
      retentionDays: nil,
      storageURL: directory.appendingPathComponent("count.json")
    )
    history.add(text: "one")
    history.add(text: "two")
    history.add(text: "three")
    try expect(history.items.map(\.text) == ["three", "two"], "count retention")
  }

  @MainActor
  private static func testTimeRetention(in directory: URL) throws {
    let history = ClipboardHistory(
      maxItems: nil,
      retentionDays: 7,
      storageURL: directory.appendingPathComponent("time.json")
    )
    let now = Date(timeIntervalSince1970: 2_000_000)
    history.add(text: "expired", at: now.addingTimeInterval(-8 * 86_400))
    history.add(text: "fresh", at: now)
    history.prune(referenceDate: now)
    try expect(history.items.map(\.text) == ["fresh"], "time retention")
  }

  @MainActor
  private static func testUnlimitedRetention(in directory: URL) throws {
    let history = ClipboardHistory(
      maxItems: nil,
      retentionDays: nil,
      storageURL: directory.appendingPathComponent("unlimited.json")
    )
    for index in 0..<150 {
      history.add(text: "item-\(index)")
    }
    try expect(history.items.count == 150, "unlimited retention")
  }

  @MainActor
  private static func testPersistence(in directory: URL) throws {
    let url = directory.appendingPathComponent("persistence.json")
    let original = ClipboardHistory(maxItems: 10, retentionDays: nil, storageURL: url)
    original.add(text: "persisted")
    let restored = ClipboardHistory(maxItems: 10, retentionDays: nil, storageURL: url)
    try expect(restored.items.map(\.text) == ["persisted"], "persistence")
  }

  @MainActor
  private static func testPrivateFilePermissions(in directory: URL) throws {
    let url = directory.appendingPathComponent("permissions.json")
    let history = ClipboardHistory(maxItems: 10, retentionDays: nil, storageURL: url)
    history.add(text: "private")
    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
    let permissions = attributes[.posixPermissions] as? NSNumber
    try expect(permissions?.intValue == 0o600, "private history permissions")
  }

  private static func testLegacyDataMigration(in directory: URL) throws {
    let legacyDirectory = directory.appendingPathComponent("legacy", isDirectory: true)
    let currentDirectory = directory.appendingPathComponent("current", isDirectory: true)
    try FileManager.default.createDirectory(
      at: legacyDirectory,
      withIntermediateDirectories: true
    )
    let legacyConfig = Data(#"{"maxItems":42}"#.utf8)
    let legacyHistory = Data(#"[{"text":"legacy"}]"#.utf8)
    try legacyConfig.write(to: legacyDirectory.appendingPathComponent("config.json"))
    try legacyHistory.write(to: legacyDirectory.appendingPathComponent("history.json"))

    try AppPaths.migrateLegacyData(from: legacyDirectory, to: currentDirectory)

    let migratedConfig = try Data(
      contentsOf: currentDirectory.appendingPathComponent("config.json")
    )
    let migratedHistoryURL =
      currentDirectory
      .appendingPathComponent("Clipboard", isDirectory: true)
      .appendingPathComponent("history.json")
    let migratedHistory = try Data(contentsOf: migratedHistoryURL)
    try expect(migratedConfig == legacyConfig, "legacy config migration")
    try expect(migratedHistory == legacyHistory, "legacy history migration")
    try expect(
      FileManager.default.fileExists(
        atPath: legacyDirectory.appendingPathComponent("history.json").path
      ),
      "legacy migration keeps source data"
    )

    let permissions =
      try FileManager.default.attributesOfItem(
        atPath: migratedHistoryURL.path
      )[.posixPermissions] as? NSNumber
    try expect(permissions?.intValue == 0o600, "migrated history permissions")
  }

  @MainActor
  private static func makeHistory(in directory: URL, name: String) -> ClipboardHistory {
    ClipboardHistory(
      maxItems: 10,
      retentionDays: nil,
      storageURL: directory.appendingPathComponent("\(name).json")
    )
  }

  private static func expect(_ condition: @autoclosure () -> Bool, _ name: String) throws {
    guard condition() else {
      throw CoreTestError.failed(name)
    }
  }

  private static func testConfigurationDefaults() throws {
    let data = Data(#"{"maxItems":null,"retentionDays":7}"#.utf8)
    let settings = try JSONDecoder().decode(AppSettings.self, from: data).validated()
    try expect(settings.maxItems == nil, "explicit unlimited item count")
    try expect(settings.retentionDays == 7, "configured retention days")
    try expect(settings.hotKey == .default, "default hot key")
    try expect(settings.showDockIcon, "default dock icon visibility")
    try expect(settings.maxTextBytes == AppSettings.default.maxTextBytes, "default max bytes")
  }

  private static func testConfigurationValidation() throws {
    var settings = AppSettings.default
    settings.hotKey = HotKeyConfiguration(
      key: "K",
      modifiers: ["command", "shift"]
    )
    let validated = try settings.validated()
    try expect(validated.hotKey.displayText == "⇧⌘K", "hot-key display")

    settings.pollIntervalMilliseconds = 50
    do {
      _ = try settings.validated()
      throw CoreTestError.failed("invalid polling interval was accepted")
    } catch is ConfigurationError {
      // Expected.
    }
  }
}

private enum CoreTestError: LocalizedError {
  case failed(String)

  var errorDescription: String? {
    switch self {
    case .failed(let name):
      return "Core test failed: \(name)"
    }
  }
}
