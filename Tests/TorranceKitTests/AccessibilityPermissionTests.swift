import Combine
import XCTest
@testable import TorranceKit

@MainActor
final class AccessibilityPermissionTests: XCTestCase {
  func testTrustIsNotQueriedUntilTheApplicationStarts() {
    var checks = 0
    let permission = AccessibilityPermission(
      checkTrust: { checks += 1; return true }, prompt: {}, openSettings: {}
    )
    XCTAssertEqual(checks, 0)
    permission.startMonitoring()
    defer { permission.stopMonitoring() }
    XCTAssertTrue(permission.isTrusted)
    XCTAssertEqual(checks, 1)
  }

  func testRefreshPublishesGrantAndRevocationWithoutRepublishingUnchangedState() {
    var trusted = false
    let permission = AccessibilityPermission(checkTrust: { trusted }, prompt: {}, openSettings: {})
    var values: [Bool] = []
    let subscription = permission.$isTrusted.sink { values.append($0) }
    trusted = true
    permission.refresh()
    permission.refresh()
    trusted = false
    permission.refresh()
    XCTAssertEqual(values, [false, true, false])
    withExtendedLifetime(subscription) {}
  }

  func testAlreadyGrantedPermissionIsRefreshedBeforeHandlingOldRequestButton() {
    var trusted = false
    var actions: [String] = []
    let permission = AccessibilityPermission(
      checkTrust: { trusted }, prompt: { actions.append("prompt") },
      openSettings: { actions.append("settings") }
    )
    permission.onWillRequest = { actions.append("hide") }
    trusted = true
    permission.request()
    XCTAssertTrue(permission.isTrusted)
    XCTAssertTrue(actions.isEmpty)
  }

  func testAllAppWindowsAreHiddenBeforePromptAndSystemSettingsOpen() {
    var actions: [String] = []
    let permission = AccessibilityPermission(
      checkTrust: { false }, prompt: { actions.append("prompt") },
      openSettings: { actions.append("settings") }
    )
    permission.onWillRequest = { actions.append("hide") }
    permission.request()
    XCTAssertEqual(actions, ["hide", "prompt", "settings"])
  }
}
