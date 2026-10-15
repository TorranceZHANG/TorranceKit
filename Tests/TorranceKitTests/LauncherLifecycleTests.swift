import XCTest
@testable import TorranceKit

private actor ControlledCatalog {
  private var pending: [CheckedContinuation<[ApplicationEntry], Never>] = []
  var count: Int { pending.count }
  func load() async -> [ApplicationEntry] {
    await withCheckedContinuation { pending.append($0) }
  }
  func complete(at index: Int, name: String) {
    pending[index].resume(returning: [ApplicationEntry(name: name, url: URL(fileURLWithPath: "/Applications/\(name).app"))])
  }
}

@MainActor
final class LauncherLifecycleTests: XCTestCase {
  func testLateCatalogResultCannotPublishAfterHide() async throws {
    let catalog = ControlledCatalog()
    let model = LauncherModel(applicationLoader: { await catalog.load() })
    model.show(settings: .default)
    model.query = "Chrome"
    for _ in 0..<100 where await catalog.count == 0 { try await Task.sleep(nanoseconds: 1_000_000) }
    let count = await catalog.count
    XCTAssertEqual(count, 1)
    guard count == 1 else { model.hide(); return }
    model.hide()
    await catalog.complete(at: 0, name: "Google Chrome")
    try await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertFalse(model.results.contains(where: { $0.title == "Google Chrome" }))
    XCTAssertFalse(model.isLoadingApplications)
  }

  func testOlderCatalogCannotReplaceNewPresentation() async throws {
    let catalog = ControlledCatalog()
    let model = LauncherModel(applicationLoader: { await catalog.load() })
    model.show(settings: .default)
    for _ in 0..<100 where await catalog.count < 1 { try await Task.sleep(nanoseconds: 1_000_000) }
    model.show(settings: .default)
    model.query = "Calendar"
    for _ in 0..<100 where await catalog.count < 2 { try await Task.sleep(nanoseconds: 1_000_000) }
    let count = await catalog.count
    XCTAssertEqual(count, 2)
    guard count == 2 else { return }
    await catalog.complete(at: 1, name: "Calendar")
    try await Task.sleep(nanoseconds: 20_000_000)
    await catalog.complete(at: 0, name: "Old Calendar")
    try await Task.sleep(nanoseconds: 20_000_000)
    XCTAssertEqual(model.results.first?.title, "Calendar")
  }
}
