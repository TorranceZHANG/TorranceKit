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

  func testSearchFindsImageByTypeAndDimensions() {
    let state = PickerState()
    let image = ClipboardItem(
      imageFileName: "image.png",
      imageDigest: "digest",
      imagePixelWidth: 1920,
      imagePixelHeight: 1080,
      imageByteCount: 1024
    )
    state.query = "图片"

    XCTAssertEqual(state.filteredItems(from: [ClipboardItem(text: "hello"), image]), [image])
  }

  func testBackgroundInstallerLaunchDoesNotShowPicker() {
    XCTAssertFalse(
      AppLaunchBehavior.shouldShowPicker(
        arguments: ["TorranceKit", AppLaunchBehavior.backgroundLaunchArgument]
      )
    )
    XCTAssertTrue(AppLaunchBehavior.shouldShowPicker(arguments: ["TorranceKit"]))
  }

  func testPickerOnlyMovesToTheActiveSpace() {
    let behavior = PickerPanelController.collectionBehavior
    XCTAssertTrue(behavior.contains(.moveToActiveSpace))
    XCTAssertTrue(behavior.contains(.transient))
    XCTAssertFalse(behavior.contains(.canJoinAllSpaces))
  }

  func testPickerUsesAnActivatingKeyPanel() {
    let styleMask = PickerPanelController.styleMask
    XCTAssertTrue(styleMask.contains(.borderless))
    XCTAssertTrue(styleMask.contains(.fullSizeContentView))
    XCTAssertFalse(styleMask.contains(.nonactivatingPanel))
  }

  func testLongTextPreviewIsBoundedWithoutChangingTheOriginal() {
    let text = String(repeating: "a", count: 200_001)
    let preview = ClipboardPreviewLoader.textPreview(for: text)

    XCTAssertTrue(preview.isTruncated)
    XCTAssertEqual(preview.text.count, 200_000)
    XCTAssertEqual(text.count, 200_001)
  }
}
