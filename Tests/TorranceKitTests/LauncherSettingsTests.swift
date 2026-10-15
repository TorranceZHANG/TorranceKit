import XCTest
@testable import TorranceKit

final class LauncherSettingsTests: XCTestCase {
  func testNewConfigurationUsesTwoDifferentDoubleTapBindings() {
    XCTAssertEqual(AppSettings.default.hotKey, .clipboardDefault)
    XCTAssertEqual(AppSettings.default.launcher.hotKey, .launcherDefault)
  }

  func testActualLegacyConfigurationKeepsOptionV() throws {
    // The 0.2.1 config.example.json hotKey section, before launcher existed.
    let data = Data(#"{"hotKey":{"doubleTapIntervalMilliseconds":400,"doubleTapModifier":"control","key":"V","mode":"keyCombination","modifiers":["option"]},"autoPaste":true,"pasteDelayMilliseconds":160}"#.utf8)
    let settings = try JSONDecoder().decode(AppSettings.self, from: data).validated()
    XCTAssertEqual(settings.hotKey, .default)
    XCTAssertEqual(settings.launcher.hotKey, .launcherDefault)
    XCTAssertEqual(settings, try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings)))
  }

  func testLegacyCommandDoubleTapGetsNonConflictingLauncherFallback() throws {
    let data = Data(#"{"hotKey":{"mode":"doubleTapModifier","doubleTapModifier":"command"}}"#.utf8)
    let settings = try JSONDecoder().decode(AppSettings.self, from: data).validated()
    XCTAssertEqual(settings.hotKey.doubleTapModifier, "command")
    XCTAssertEqual(settings.launcher.hotKey.mode, .keyCombination)
    XCTAssertFalse(settings.hotKey.conflicts(with: settings.launcher.hotKey))
  }

  func testSameDoubleTapWithDifferentIntervalsIsRejected() {
    var settings = AppSettings.default
    settings.launcher.hotKey = settings.hotKey
    settings.launcher.hotKey.doubleTapIntervalMilliseconds = 700
    XCTAssertThrowsError(try settings.validated())
  }

  func testSameCombinationWithDifferentModifierOrderIsRejected() {
    var settings = AppSettings.default
    settings.hotKey = HotKeyConfiguration(key: "K", modifiers: ["control", "option"])
    settings.launcher.hotKey = HotKeyConfiguration(key: "k", modifiers: ["OPTION", "CONTROL"])
    XCTAssertThrowsError(try settings.validated())
  }

  func testVisualPresetPreservesOtherOptions() throws {
    var settings = AppSettings.default
    settings.retentionDays = 17
    settings.launcher.webSearchEnabled = false
    settings.launcher.searchEngine = .baidu
    settings.hotKey = .default
    var draft = SettingsDraft(settings: settings)
    draft.useDoubleTapPreset()
    let result = try draft.makeSettings()
    XCTAssertEqual(result.retentionDays, 17)
    XCTAssertFalse(result.launcher.webSearchEnabled)
    XCTAssertEqual(result.launcher.searchEngine, .baidu)
    XCTAssertEqual(result.hotKey, .clipboardDefault)
    XCTAssertEqual(result.launcher.hotKey, .launcherDefault)
  }

  func testDoubleTapDoesNotValidateHiddenCombinationModifierSelection() throws {
    var draft = SettingsDraft(settings: .default)
    draft.launcher.hotKey.modifiers = []
    draft.usesCommand = false
    draft.usesControl = false
    draft.usesOption = false
    draft.usesShift = false
    let settings = try draft.makeSettings()
    XCTAssertEqual(settings.hotKey.mode, .doubleTapModifier)
    XCTAssertEqual(settings.launcher.hotKey.mode, .doubleTapModifier)
  }
}
