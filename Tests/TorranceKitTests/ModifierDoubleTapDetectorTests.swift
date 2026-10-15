import XCTest

@testable import TorranceKit

final class ModifierDoubleTapDetectorTests: XCTestCase {
  func testTriggersAfterTwoCompletedQuickTaps() {
    var detector = ModifierDoubleTapDetector(maximumInterval: 0.4)

    XCTAssertFalse(handle(&detector, pressed: true, at: 1.00))
    XCTAssertFalse(handle(&detector, pressed: false, at: 1.08))
    XCTAssertFalse(handle(&detector, pressed: true, at: 1.28))
    XCTAssertTrue(handle(&detector, pressed: false, at: 1.32))
    XCTAssertFalse(handle(&detector, pressed: false, at: 1.35))
  }

  func testCommandCopyDoesNotTriggerLauncher() {
    var detector = ModifierDoubleTapDetector(maximumInterval: 0.4)
    XCTAssertFalse(handle(&detector, pressed: true, at: 1.0))
    detector.cancel() // C keyDown while Command is held.
    XCTAssertFalse(handle(&detector, pressed: false, at: 1.05))
    XCTAssertFalse(handle(&detector, pressed: true, at: 1.15))
    detector.cancel()
    XCTAssertFalse(handle(&detector, pressed: false, at: 1.20))
  }

  func testSecondTapUsedAsACommandShortcutCancels() {
    var detector = ModifierDoubleTapDetector(maximumInterval: 0.4)
    XCTAssertFalse(handle(&detector, pressed: true, at: 1.0))
    XCTAssertFalse(handle(&detector, pressed: false, at: 1.05))
    XCTAssertFalse(handle(&detector, pressed: true, at: 1.15))
    detector.cancel()
    XCTAssertFalse(handle(&detector, pressed: false, at: 1.20))
  }

  func testHoldingSecondTapDoesNotTrigger() {
    var detector = ModifierDoubleTapDetector(maximumInterval: 0.4)
    XCTAssertFalse(handle(&detector, pressed: true, at: 1.0))
    XCTAssertFalse(handle(&detector, pressed: false, at: 1.05))
    XCTAssertFalse(handle(&detector, pressed: true, at: 1.15))
    XCTAssertFalse(handle(&detector, pressed: false, at: 2.0))
  }

  func testDoesNotTriggerWithoutAReleaseBetweenPresses() {
    var detector = ModifierDoubleTapDetector(maximumInterval: 0.4)

    XCTAssertFalse(handle(&detector, pressed: true, at: 1.00))
    XCTAssertFalse(handle(&detector, pressed: true, at: 1.15))
  }

  func testDoesNotTriggerWhenSecondTapIsTooLate() {
    var detector = ModifierDoubleTapDetector(maximumInterval: 0.4)

    XCTAssertFalse(handle(&detector, pressed: true, at: 1.00))
    XCTAssertFalse(handle(&detector, pressed: false, at: 1.08))
    XCTAssertFalse(handle(&detector, pressed: true, at: 1.50))
  }

  func testOtherModifierCancelsTheSequence() {
    var detector = ModifierDoubleTapDetector(maximumInterval: 0.4)

    XCTAssertFalse(handle(&detector, pressed: true, at: 1.00))
    XCTAssertFalse(handle(&detector, pressed: false, at: 1.08))
    XCTAssertFalse(
      detector.handle(
        isPressed: false,
        timestamp: 1.15,
        hasOtherStandardModifiers: true
      )
    )
    XCTAssertFalse(handle(&detector, pressed: true, at: 1.25))
  }

  private func handle(
    _ detector: inout ModifierDoubleTapDetector,
    pressed: Bool,
    at timestamp: TimeInterval
  ) -> Bool {
    detector.handle(
      isPressed: pressed,
      timestamp: timestamp,
      hasOtherStandardModifiers: false
    )
  }
}
