import XCTest
@testable import TorranceKit

final class HotKeyTransactionTests: XCTestCase {
  private enum Failure: Error { case occupied, disk, rollback }

  func testSwappingBindingsReleasesBothBeforeRegistering() throws {
    var active = ["command", "control"]
    var persisted = false
    try HotKeyTransaction.apply(
      previous: active, candidate: ["control", "command"], unregister: { active = [] },
      register: { bindings in
        for binding in bindings {
          if active.contains(binding) { throw Failure.occupied }
          active.append(binding)
        }
      }, persist: { persisted = true }
    )
    XCTAssertEqual(active, ["control", "command"])
    XCTAssertTrue(persisted)
  }

  func testPartialRegistrationFailureRestoresBothBindings() {
    var active = ["command", "control"]
    var persisted = false
    XCTAssertThrowsError(try HotKeyTransaction.apply(
      previous: active, candidate: ["option", "occupied"], unregister: { active = [] },
      register: { bindings in
        for binding in bindings {
          if binding == "occupied" { throw Failure.occupied }
          active.append(binding)
        }
      }, persist: { persisted = true }
    ))
    XCTAssertEqual(active, ["command", "control"])
    XCTAssertFalse(persisted)
  }

  func testDiskFailureRestoresBothBindings() {
    var active = ["command", "control"]
    XCTAssertThrowsError(try HotKeyTransaction.apply(
      previous: active, candidate: ["option", "shift"], unregister: { active = [] },
      register: { active = $0 }, persist: { throw Failure.disk }
    ))
    XCTAssertEqual(active, ["command", "control"])
  }

  func testRollbackFailureIsReported() {
    XCTAssertThrowsError(try HotKeyTransaction.apply(
      previous: ["old"], candidate: ["new"], unregister: {},
      register: { _ in throw Failure.rollback }, persist: {}
    )) { error in
      XCTAssertTrue(error.localizedDescription.contains("恢复原快捷键失败"))
    }
  }
}
