import AppKit
import Carbon.HIToolbox
import XCTest
@testable import TorranceKit

@MainActor
final class HotKeyRoutingTests: XCTestCase {
  func testTwoCarbonHandlersRouteIndependentlyAndUnknownEventsRemainUnhandled() throws {
    let clipboard = GlobalHotKey(identifier: 1, configuration: .clipboardDefault)
    let launcher = GlobalHotKey(identifier: 2, configuration: .launcherDefault)
    defer { clipboard.unregisterTrigger(); launcher.unregisterTrigger() }
    var clipboardCount = 0
    var launcherCount = 0
    clipboard.onPressed = { clipboardCount += 1 }
    launcher.onPressed = { launcherCount += 1 }
    XCTAssertEqual(try dispatch(id: 1), noErr)
    XCTAssertEqual(try dispatch(id: 2), noErr)
    XCTAssertEqual(clipboardCount, 1)
    XCTAssertEqual(launcherCount, 1)
    XCTAssertEqual(try dispatch(id: 99), OSStatus(eventNotHandledErr))
    withExtendedLifetime((clipboard, launcher)) {}
  }

  private func dispatch(id: UInt32) throws -> OSStatus {
    var event: EventRef?
    XCTAssertEqual(CreateEvent(nil, OSType(kEventClassKeyboard), UInt32(kEventHotKeyPressed), 0, 0, &event), noErr)
    let eventRef = try XCTUnwrap(event)
    defer { ReleaseEvent(eventRef) }
    var hotKeyID = EventHotKeyID(signature: 0x544B_5452, id: id)
    XCTAssertEqual(SetEventParameter(eventRef, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &hotKeyID), noErr)
    return SendEventToEventTarget(eventRef, GetApplicationEventTarget())
  }
}
