import XCTest

@testable import TorranceKit

@MainActor
final class PickerStateTests: XCTestCase {
  func testHoverSelectionDoesNotRequestAutomaticScrolling() {
    let state = PickerState()
    let initialRequest = state.selectionScrollRequest

    state.selectedIndex = 4

    XCTAssertEqual(state.selectedIndex, 4)
    XCTAssertEqual(state.selectionScrollRequest, initialRequest)
  }

  func testKeyboardMovementRequestsAutomaticScrolling() {
    let state = PickerState()
    let initialRequest = state.selectionScrollRequest

    state.moveSelection(by: 1, itemCount: 10)

    XCTAssertEqual(state.selectedIndex, 1)
    XCTAssertEqual(state.selectionScrollRequest, initialRequest + 1)
  }

  func testSearchResetRequestsScrollingToFirstResult() {
    let state = PickerState()
    state.selectedIndex = 7
    let initialRequest = state.selectionScrollRequest

    state.selectFirstAndRequestScroll()

    XCTAssertEqual(state.selectedIndex, 0)
    XCTAssertEqual(state.selectionScrollRequest, initialRequest + 1)
  }
}
