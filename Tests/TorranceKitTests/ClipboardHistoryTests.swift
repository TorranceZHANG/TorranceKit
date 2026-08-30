import XCTest

@testable import TorranceKit

@MainActor
final class ClipboardHistoryTests: XCTestCase {
  private var temporaryDirectory: URL!
  private var historyURL: URL!

  override func setUpWithError() throws {
    temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    historyURL = temporaryDirectory.appendingPathComponent("history.json")
  }

  override func tearDownWithError() throws {
    if let temporaryDirectory {
      try? FileManager.default.removeItem(at: temporaryDirectory)
    }
  }

  func testAddsNewestFirstAndRejectsBlankText() {
    let history = ClipboardHistory(maxItems: 10, retentionDays: nil, storageURL: historyURL)

    history.add(text: "first")
    history.add(text: "   \n")
    history.add(text: "second")

    XCTAssertEqual(history.items.map(\.text), ["second", "first"])
  }

  func testDuplicateMovesToFrontWithoutCreatingAnotherItem() {
    let history = ClipboardHistory(maxItems: 10, retentionDays: nil, storageURL: historyURL)
    history.add(text: "first")
    history.add(text: "second")
    history.add(text: "first")

    XCTAssertEqual(history.items.map(\.text), ["first", "second"])
    XCTAssertEqual(history.items.first?.copyCount, 2)
  }

  func testHonorsMaximumItemCount() {
    let history = ClipboardHistory(maxItems: 2, retentionDays: nil, storageURL: historyURL)
    history.add(text: "one")
    history.add(text: "two")
    history.add(text: "three")

    XCTAssertEqual(history.items.map(\.text), ["three", "two"])
  }

  func testPersistsAndLoadsHistory() {
    let original = ClipboardHistory(maxItems: 10, retentionDays: nil, storageURL: historyURL)
    original.add(text: "persisted")

    let restored = ClipboardHistory(maxItems: 10, retentionDays: nil, storageURL: historyURL)
    XCTAssertEqual(restored.items.map(\.text), ["persisted"])
  }

  func testLoadsLegacyTextItemWithoutKind() throws {
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )
    let id = UUID()
    let data = Data(
      """
      [{"id":"\(id.uuidString)","text":"legacy","createdAt":"2026-08-30T00:00:00Z","copyCount":1}]
      """.utf8
    )
    try data.write(to: historyURL)

    let history = ClipboardHistory(maxItems: 10, retentionDays: nil, storageURL: historyURL)

    XCTAssertEqual(history.items.first?.kind, .text)
    XCTAssertEqual(history.items.first?.text, "legacy")
  }

  func testMarkUsedMovesItemToFront() {
    let history = ClipboardHistory(maxItems: 10, retentionDays: nil, storageURL: historyURL)
    history.add(text: "first")
    history.add(text: "second")

    let first = try! XCTUnwrap(history.items.last)
    history.markUsed(first)

    XCTAssertEqual(history.items.map(\.text), ["first", "second"])
    XCTAssertNotNil(history.items.first?.lastUsedAt)
  }

  func testRetentionDaysRemovesExpiredItems() {
    let history = ClipboardHistory(maxItems: nil, retentionDays: 7, storageURL: historyURL)
    let now = Date(timeIntervalSince1970: 2_000_000)
    let eightDaysAgo = now.addingTimeInterval(-8 * 24 * 60 * 60)
    history.add(text: "expired", at: eightDaysAgo)
    history.add(text: "fresh", at: now)

    history.prune(referenceDate: now)

    XCTAssertEqual(history.items.map(\.text), ["fresh"])
  }

  func testNilLimitsKeepAllItems() {
    let history = ClipboardHistory(maxItems: nil, retentionDays: nil, storageURL: historyURL)
    for index in 0..<150 {
      history.add(text: "item-\(index)")
    }

    XCTAssertEqual(history.items.count, 150)
  }

  func testHistoryFileUsesPrivatePermissions() throws {
    let history = ClipboardHistory(maxItems: 10, retentionDays: nil, storageURL: historyURL)
    history.add(text: "private")

    let attributes = try FileManager.default.attributesOfItem(atPath: historyURL.path)
    let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
    XCTAssertEqual(permissions.intValue, 0o600)
  }
}
