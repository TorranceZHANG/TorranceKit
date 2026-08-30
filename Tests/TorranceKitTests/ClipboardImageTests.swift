import AppKit
import XCTest

@testable import TorranceKit

@MainActor
final class ClipboardImageTests: XCTestCase {
  private var temporaryDirectory: URL!
  private var historyURL: URL!
  private var imageDirectoryURL: URL!

  override func setUpWithError() throws {
    temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent("TorranceKitImageTests-\(UUID().uuidString)")
    historyURL = temporaryDirectory.appendingPathComponent("history.json")
    imageDirectoryURL = temporaryDirectory.appendingPathComponent("images", isDirectory: true)
  }

  override func tearDownWithError() throws {
    if let temporaryDirectory {
      try? FileManager.default.removeItem(at: temporaryDirectory)
    }
  }

  func testImagePersistsOutsideHistoryJSONWithPrivatePermissions() throws {
    let pngData = try makePNGData(red: 0.12, green: 0.48, blue: 0.95)
    let history = makeHistory()

    XCTAssertTrue(
      history.add(imagePNGData: pngData, pixelWidth: 3, pixelHeight: 2)
    )
    let item = try XCTUnwrap(history.items.first)
    let fileName = try XCTUnwrap(item.imageFileName)
    let imageURL = imageDirectoryURL.appendingPathComponent(fileName)

    XCTAssertEqual(item.kind, .image)
    XCTAssertEqual(item.imagePixelWidth, 3)
    XCTAssertEqual(item.imagePixelHeight, 2)
    XCTAssertEqual(history.payload(for: item), .image(pngData: pngData))
    XCTAssertEqual(try Data(contentsOf: imageURL), pngData)

    let attributes = try FileManager.default.attributesOfItem(atPath: imageURL.path)
    let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
    XCTAssertEqual(permissions.intValue, 0o600)

    let historyData = try Data(contentsOf: historyURL)
    let historyJSON = try XCTUnwrap(String(data: historyData, encoding: .utf8))
    XCTAssertFalse(historyJSON.contains(pngData.base64EncodedString()))

    let restored = makeHistory()
    XCTAssertEqual(restored.items.first?.kind, .image)
    XCTAssertEqual(restored.imageData(for: try XCTUnwrap(restored.items.first)), pngData)
  }

  func testDuplicateImageMovesToFrontWithoutCreatingAnotherFile() throws {
    let pngData = try makePNGData(red: 0.20, green: 0.78, blue: 0.35)
    let history = makeHistory()
    history.add(text: "text")
    history.add(imagePNGData: pngData, pixelWidth: 3, pixelHeight: 2)
    history.add(imagePNGData: pngData, pixelWidth: 3, pixelHeight: 2)

    XCTAssertEqual(history.items.count, 2)
    XCTAssertEqual(history.items.first?.kind, .image)
    XCTAssertEqual(history.items.first?.copyCount, 2)
    let imageFiles = try FileManager.default.contentsOfDirectory(
      at: imageDirectoryURL,
      includingPropertiesForKeys: nil
    )
    XCTAssertEqual(imageFiles.count, 1)
  }

  func testRemovingOrPruningImageDeletesItsFile() throws {
    let pngData = try makePNGData(red: 0.98, green: 0.55, blue: 0.12)
    let history = ClipboardHistory(
      maxItems: 1,
      retentionDays: nil,
      storageURL: historyURL,
      imageDirectoryURL: imageDirectoryURL
    )
    history.add(imagePNGData: pngData, pixelWidth: 3, pixelHeight: 2)
    let imageItem = try XCTUnwrap(history.items.first)
    let fileName = try XCTUnwrap(imageItem.imageFileName)
    let imageURL = imageDirectoryURL.appendingPathComponent(fileName)
    XCTAssertTrue(FileManager.default.fileExists(atPath: imageURL.path))

    history.add(text: "newer")

    XCTAssertFalse(FileManager.default.fileExists(atPath: imageURL.path))
  }

  func testMonitorCapturesAndCanIgnorePNG() throws {
    let pasteboard = NSPasteboard(name: .init("TorranceKitTests-\(UUID().uuidString)"))
    let pngData = try makePNGData(red: 0.58, green: 0.28, blue: 0.84)
    let history = makeHistory()
    let monitor = ClipboardMonitor(history: history, pasteboard: pasteboard)
    monitor.apply(settings: .default)

    pasteboard.clearContents()
    pasteboard.setData(pngData, forType: .png)
    monitor.poll()

    let item = try XCTUnwrap(history.items.first)
    XCTAssertEqual(item.kind, .image)
    XCTAssertEqual(history.imageData(for: item), pngData)

    monitor.ignoreNextChange(containing: .image(pngData: pngData))
    pasteboard.clearContents()
    pasteboard.setData(pngData, forType: .png)
    monitor.poll()

    XCTAssertEqual(history.items.first?.copyCount, 1)
  }

  func testImageCaptureCanBeDisabled() throws {
    let pasteboard = NSPasteboard(name: .init("TorranceKitTests-\(UUID().uuidString)"))
    let history = makeHistory()
    let monitor = ClipboardMonitor(history: history, pasteboard: pasteboard)
    var settings = AppSettings.default
    settings.capturesImages = false
    monitor.apply(settings: settings)

    pasteboard.clearContents()
    pasteboard.setData(
      try makePNGData(red: 0.92, green: 0.18, blue: 0.18),
      forType: .png
    )
    monitor.poll()

    XCTAssertTrue(history.items.isEmpty)
  }

  func testPasteControllerWritesTextAndImagePayloads() throws {
    let pasteboard = NSPasteboard(name: .init("TorranceKitTests-\(UUID().uuidString)"))
    let pngData = try makePNGData(red: 0.95, green: 0.80, blue: 0.10)

    XCTAssertTrue(PasteController.write(.text("hello"), to: pasteboard))
    XCTAssertEqual(pasteboard.string(forType: .string), "hello")

    XCTAssertTrue(PasteController.write(.image(pngData: pngData), to: pasteboard))
    XCTAssertEqual(pasteboard.data(forType: .png), pngData)
    XCTAssertNotNil(pasteboard.data(forType: .tiff))
  }

  func testImagePreviewLoaderBuildsThumbnailOffTheHistoryPath() async throws {
    let pngData = try makePNGData(red: 0.12, green: 0.48, blue: 0.95)
    let imageURL = temporaryDirectory.appendingPathComponent("preview.png")
    try FileManager.default.createDirectory(
      at: temporaryDirectory,
      withIntermediateDirectories: true
    )
    try pngData.write(to: imageURL)

    let image = await ClipboardPreviewLoader.imageThumbnail(
      at: imageURL,
      maximumPixelSize: 2
    )

    XCTAssertNotNil(image)
    XCTAssertLessThanOrEqual(image?.size.width ?? 0, 2)
    XCTAssertLessThanOrEqual(image?.size.height ?? 0, 2)
  }

  private func makeHistory() -> ClipboardHistory {
    ClipboardHistory(
      maxItems: 10,
      retentionDays: nil,
      storageURL: historyURL,
      imageDirectoryURL: imageDirectoryURL
    )
  }

  private func makePNGData(red: CGFloat, green: CGFloat, blue: CGFloat) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: 3,
      pixelsHigh: 2,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: 0,
      bitsPerPixel: 0
    ) else {
      throw ImageTestError.failedToCreateBitmap
    }
    let deviceColor = NSColor(
      deviceRed: red,
      green: green,
      blue: blue,
      alpha: 1
    )
    for x in 0..<3 {
      for y in 0..<2 {
        bitmap.setColor(deviceColor, atX: x, y: y)
      }
    }
    guard let data = bitmap.representation(using: .png, properties: [:]) else {
      throw ImageTestError.failedToCreatePNG
    }
    return data
  }
}

private enum ImageTestError: Error {
  case failedToCreateBitmap
  case failedToCreatePNG
}
