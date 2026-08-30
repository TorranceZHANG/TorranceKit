import AppKit
import ImageIO

struct ClipboardTextPreviewContent: Equatable {
  let text: String
  let isTruncated: Bool
}

private struct SendableImagePreview: @unchecked Sendable {
  let image: NSImage?
}

enum ClipboardPreviewLoader {
  static let maximumTextPreviewCharacters = 200_000
  static let maximumImagePreviewPixels = 1_600

  static func textPreview(
    for text: String,
    maximumCharacters: Int = maximumTextPreviewCharacters
  ) -> ClipboardTextPreviewContent {
    guard maximumCharacters > 0,
      let boundary = text.index(
        text.startIndex,
        offsetBy: maximumCharacters,
        limitedBy: text.endIndex
      ),
      boundary != text.endIndex
    else {
      return ClipboardTextPreviewContent(text: text, isTruncated: false)
    }

    return ClipboardTextPreviewContent(
      text: String(text[..<boundary]),
      isTruncated: true
    )
  }

  static func imageThumbnail(
    at url: URL,
    maximumPixelSize: Int = maximumImagePreviewPixels
  ) async -> NSImage? {
    guard maximumPixelSize > 0 else { return nil }
    let preview = await Task.detached(priority: .userInitiated) { () -> SendableImagePreview in
      autoreleasepool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
          return SendableImagePreview(image: nil)
        }
        let options: [CFString: Any] = [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceShouldCacheImmediately: true,
          kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
          source,
          0,
          options as CFDictionary
        ) else {
          return SendableImagePreview(image: nil)
        }
        return SendableImagePreview(
          image: NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
          )
        )
      }
    }.value
    return preview.image
  }
}
