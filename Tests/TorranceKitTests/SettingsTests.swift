import XCTest

@testable import TorranceKit

final class SettingsTests: XCTestCase {
  func testVisualDraftPreservesSettingsAndParsesExcludedApplications() throws {
    var settings = AppSettings.default
    settings.maxItems = nil
    settings.retentionDays = 14
    settings.capturesImages = false
    settings.maxImageBytes = 10_485_760
    settings.hotKey = HotKeyConfiguration(
      key: "K",
      modifiers: ["command", "shift"]
    )
    settings.excludedBundleIdentifiers = ["com.example.First"]

    var draft = SettingsDraft(settings: settings)
    draft.excludedBundleIdentifiersText = """
      com.example.Second

      com.example.First
      com.example.Second
      """

    let result = try draft.makeSettings()

    XCTAssertNil(result.maxItems)
    XCTAssertEqual(result.retentionDays, 14)
    XCTAssertFalse(result.capturesImages)
    XCTAssertEqual(result.maxImageBytes, 10_485_760)
    XCTAssertEqual(result.hotKey.key, "K")
    XCTAssertEqual(Set(result.hotKey.modifiers), ["command", "shift"])
    XCTAssertEqual(
      result.excludedBundleIdentifiers,
      ["com.example.First", "com.example.Second"]
    )
  }

  func testVisualDraftRejectsShortcutWithoutModifier() {
    var draft = SettingsDraft(settings: .default)
    draft.triggerMode = .keyCombination
    draft.usesCommand = false
    draft.usesControl = false
    draft.usesOption = false
    draft.usesShift = false

    XCTAssertThrowsError(try draft.makeSettings())
  }

  func testVisualDraftPreservesDoubleTapTrigger() throws {
    var settings = AppSettings.default
    settings.hotKey = HotKeyConfiguration(
      mode: .doubleTapModifier,
      key: "V",
      modifiers: ["option"],
      doubleTapModifier: "control",
      doubleTapIntervalMilliseconds: 500
    )

    let result = try SettingsDraft(settings: settings).makeSettings()

    XCTAssertEqual(result.hotKey.mode, .doubleTapModifier)
    XCTAssertEqual(result.hotKey.doubleTapModifier, "control")
    XCTAssertEqual(result.hotKey.doubleTapIntervalMilliseconds, 500)
  }

  @MainActor
  func testVisualSaveWritesReadablePrivateJSON() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("TorranceKitSettingsTests-\(UUID().uuidString)")
    let fileURL = root.appendingPathComponent("config.json")
    defer { try? FileManager.default.removeItem(at: root) }

    let configuration = AppConfiguration(fileURL: fileURL)
    var settings = AppSettings.default
    settings.maxItems = 4321
    settings.retentionDays = nil
    settings.hotKey = HotKeyConfiguration(key: "B", modifiers: ["control", "option"])

    try configuration.writeToDisk(settings)
    let restored = try configuration.readFromDisk()

    XCTAssertEqual(restored, try settings.validated())
    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
    let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
    XCTAssertEqual(permissions.intValue, 0o600)
  }
}
