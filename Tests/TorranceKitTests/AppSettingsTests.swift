import XCTest

@testable import TorranceKit

final class AppSettingsTests: XCTestCase {
  func testMissingFieldsUseDefaultsAndNullDisablesLimit() throws {
    let data = Data(#"{"maxItems":null,"retentionDays":7}"#.utf8)
    let settings = try JSONDecoder().decode(AppSettings.self, from: data).validated()

    XCTAssertNil(settings.maxItems)
    XCTAssertEqual(settings.retentionDays, 7)
    XCTAssertEqual(settings.hotKey, .default)
    XCTAssertTrue(settings.capturesImages)
    XCTAssertEqual(settings.maxTextBytes, AppSettings.default.maxTextBytes)
    XCTAssertEqual(settings.maxImageBytes, AppSettings.default.maxImageBytes)
  }

  func testHotKeyIsNormalized() throws {
    let hotKey = HotKeyConfiguration(
      key: " k ",
      modifiers: ["Command", "SHIFT"]
    )

    let validated = try hotKey.validated()

    XCTAssertEqual(validated.key, "K")
    XCTAssertEqual(validated.modifiers, ["command", "shift"])
    XCTAssertEqual(validated.displayText, "⇧⌘K")
  }

  func testLegacyHotKeyJSONDefaultsToKeyCombination() throws {
    let data = Data(#"{"key":"V","modifiers":["option"]}"#.utf8)

    let configuration = try JSONDecoder().decode(HotKeyConfiguration.self, from: data)

    XCTAssertEqual(configuration.mode, .keyCombination)
    XCTAssertEqual(configuration.doubleTapModifier, "control")
    XCTAssertEqual(configuration.doubleTapIntervalMilliseconds, 400)
  }

  func testDoubleTapModifierConfiguration() throws {
    let configuration = HotKeyConfiguration(
      mode: .doubleTapModifier,
      key: "V",
      modifiers: ["option"],
      doubleTapModifier: " Control ",
      doubleTapIntervalMilliseconds: 500
    )

    let validated = try configuration.validated()

    XCTAssertEqual(validated.mode, .doubleTapModifier)
    XCTAssertEqual(validated.doubleTapModifier, "control")
    XCTAssertEqual(validated.displayText, "双击 ⌃Ctrl")
  }

  func testRejectsInvalidDoubleTapInterval() {
    let configuration = HotKeyConfiguration(
      mode: .doubleTapModifier,
      key: "V",
      modifiers: ["option"],
      doubleTapIntervalMilliseconds: 900
    )

    XCTAssertThrowsError(try configuration.validated())
  }

  func testRejectsHotKeyWithoutModifier() {
    XCTAssertThrowsError(
      try HotKeyConfiguration(key: "V", modifiers: []).validated()
    )
  }

  func testRejectsPollingIntervalBelowMinimum() {
    var settings = AppSettings.default
    settings.pollIntervalMilliseconds = 50
    XCTAssertThrowsError(try settings.validated())
  }

  func testRejectsImageLimitAboveMaximum() {
    var settings = AppSettings.default
    settings.maxImageBytes = 52_428_801
    XCTAssertThrowsError(try settings.validated())
  }
}
