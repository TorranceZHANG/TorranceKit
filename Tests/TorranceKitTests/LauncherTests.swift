import AppKit
import XCTest
@testable import TorranceKit

final class LauncherTests: XCTestCase {
  // Names and locations from the actual system and installed application catalog.
  private let applications = [
    ApplicationEntry(name: "Calculator", url: URL(fileURLWithPath: "/System/Applications/Calculator.app")),
    ApplicationEntry(name: "Calendar", url: URL(fileURLWithPath: "/System/Applications/Calendar.app")),
    ApplicationEntry(name: "Google Chrome", url: URL(fileURLWithPath: "/Applications/Google Chrome.app"))
  ]

  func testCalculatorAndDecimalAreNotTreatedAsWebsites() {
    for (query, answer) in [("1+2*3", "7"), ("1.5", "1.5"), ("2.0e-3", "0.002"), ("=sqrt(16)", "4")] {
      let results = LauncherQueryEngine.results(query: query, applications: applications, settings: .default)
      XCTAssertEqual(results.first?.action, .copy(answer))
    }
  }

  func testApplicationMatchOrdersPrefixBeforeSubstring() {
    let results = LauncherQueryEngine.results(query: "cal", applications: applications, settings: .default)
    XCTAssertEqual(results.prefix(2).map(\.title), ["Calculator", "Calendar"])
    XCTAssertEqual(results.last?.symbol, "globe")
  }

  func testMathConstantsRouteToCalculatorWithoutHidingApplicationNames() {
    for (query, expected) in [("e", M_E), ("pi*2", Double.pi * 2), ("e^2", 7.38905609893065)] {
      let result = LauncherQueryEngine.results(query: query, applications: [], settings: .default).first
      guard case .copy(let answer) = result?.action, let value = Double(answer) else {
        XCTFail("Expected calculator result for \(query)"); continue
      }
      XCTAssertEqual(value, expected, accuracy: 1e-13)
    }
    let pixelmator = ApplicationEntry(name: "Pixelmator Pro", url: URL(fileURLWithPath: "/Applications/Pixelmator Pro.app"))
    XCTAssertEqual(LauncherQueryEngine.results(query: "Pixelmator", applications: [pixelmator], settings: .default).first?.action, .openApplication(pixelmator.url))
  }

  func testInitialsFindGoogleChrome() {
    let results = LauncherQueryEngine.results(query: "gc", applications: applications, settings: .default)
    XCTAssertEqual(results.first?.title, "Google Chrome")
  }

  func testWebSearchEncodesChineseAndReservedCharacters() throws {
    let term = "剪贴板 & a+b?#"
    let results = LauncherQueryEngine.results(query: "bing \(term)", applications: [], settings: .default)
    guard case .openURL(let url) = results.first?.action else { return XCTFail("missing web result") }
    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    XCTAssertEqual(components.host, "www.bing.com")
    XCTAssertEqual(components.queryItems?.first?.value, term)
    XCTAssertTrue(url.absoluteString.contains("a%2Bb"))
  }

  func testOnlyWebsiteSchemesAreRecognized() {
    XCTAssertEqual(LauncherQueryEngine.websiteURL("example.com")?.scheme, "https")
    XCTAssertNotNil(LauncherQueryEngine.websiteURL("https://www.alfredapp.com/help/"))
    XCTAssertNil(LauncherQueryEngine.websiteURL("file:///etc/passwd"))
    XCTAssertNil(LauncherQueryEngine.websiteURL("javascript://example.com/alert(1)"))
    XCTAssertNil(LauncherQueryEngine.websiteURL("https://user:password@example.com"))
    XCTAssertNil(LauncherQueryEngine.websiteURL("2.0e-3"))
    XCTAssertNotNil(LauncherQueryEngine.websiteURL("http://devbox:8080"))
    XCTAssertNotNil(LauncherQueryEngine.websiteURL("http://[::1]:3000"))
  }

  func testFeatureTogglesAndExplicitCalculationErrors() {
    var settings = LauncherSettings.default
    settings.webSearchEnabled = false
    settings.searchesApplications = false
    XCTAssertEqual(LauncherQueryEngine.results(query: "hello", applications: applications, settings: settings), [])
    let results = LauncherQueryEngine.results(query: "=1/0", applications: [], settings: .default)
    XCTAssertEqual(results.count, 1)
    XCTAssertEqual(results.first?.action, LauncherAction.none)
    XCTAssertEqual(LauncherQueryEngine.results(query: "1/0", applications: [], settings: .default).first?.action, LauncherAction.none)
    XCTAssertEqual(LauncherQueryEngine.results(query: "1+", applications: [], settings: .default).first?.action, LauncherAction.none)
    for expression in ["sqrt(-1)", "log(0)", "1e+"] {
      XCTAssertEqual(LauncherQueryEngine.results(query: expression, applications: [], settings: .default).first?.action, LauncherAction.none)
    }
    XCTAssertEqual(LauncherQueryEngine.results(query: "clipboard", applications: [], settings: settings).first?.action, .clipboard)
  }

  func testCatalogSkipsApplicationsNestedInsideApplicationBundles() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("Outer.app/Contents/Helper.app"), withIntermediateDirectories: true
    )
    let entries = ApplicationCatalog.load(in: [root, root])
    XCTAssertEqual(entries.map(\.name), ["Outer"])
  }
}
