import Foundation

enum ClipboardItemKind: String, Codable, Hashable {
  case text
  case image
}

enum ClipboardPayload: Equatable {
  case text(String)
  case image(pngData: Data)
}

struct ClipboardItem: Codable, Identifiable, Hashable {
  let id: UUID
  let kind: ClipboardItemKind
  let text: String
  let imageFileName: String?
  let imageDigest: String?
  let imagePixelWidth: Int?
  let imagePixelHeight: Int?
  let imageByteCount: Int?
  var createdAt: Date
  var lastUsedAt: Date?
  var copyCount: Int

  init(
    id: UUID = UUID(),
    text: String,
    createdAt: Date = Date(),
    lastUsedAt: Date? = nil,
    copyCount: Int = 1
  ) {
    self.id = id
    kind = .text
    self.text = text
    imageFileName = nil
    imageDigest = nil
    imagePixelWidth = nil
    imagePixelHeight = nil
    imageByteCount = nil
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
    self.copyCount = copyCount
  }

  init(
    id: UUID = UUID(),
    imageFileName: String,
    imageDigest: String,
    imagePixelWidth: Int,
    imagePixelHeight: Int,
    imageByteCount: Int,
    createdAt: Date = Date(),
    lastUsedAt: Date? = nil,
    copyCount: Int = 1
  ) {
    self.id = id
    kind = .image
    text = ""
    self.imageFileName = imageFileName
    self.imageDigest = imageDigest
    self.imagePixelWidth = imagePixelWidth
    self.imagePixelHeight = imagePixelHeight
    self.imageByteCount = imageByteCount
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
    self.copyCount = copyCount
  }

  var summaryText: String {
    switch kind {
    case .text:
      return String(text.prefix(500))
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    case .image:
      return "图片 · \(imageDimensionsText)"
    }
  }

  var searchableText: String {
    switch kind {
    case .text:
      return text
    case .image:
      return "图片 image \(imageDimensionsText)"
    }
  }

  var imageDimensionsText: String {
    guard let imagePixelWidth, let imagePixelHeight else { return "未知尺寸" }
    return "\(imagePixelWidth) × \(imagePixelHeight)"
  }

  private enum CodingKeys: String, CodingKey {
    case id, kind, text, imageFileName, imageDigest
    case imagePixelWidth, imagePixelHeight, imageByteCount
    case createdAt, lastUsedAt, copyCount
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    kind = try container.decodeIfPresent(ClipboardItemKind.self, forKey: .kind) ?? .text
    text = try container.decodeIfPresent(String.self, forKey: .text) ?? ""
    imageFileName = try container.decodeIfPresent(String.self, forKey: .imageFileName)
    imageDigest = try container.decodeIfPresent(String.self, forKey: .imageDigest)
    imagePixelWidth = try container.decodeIfPresent(Int.self, forKey: .imagePixelWidth)
    imagePixelHeight = try container.decodeIfPresent(Int.self, forKey: .imagePixelHeight)
    imageByteCount = try container.decodeIfPresent(Int.self, forKey: .imageByteCount)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
    lastUsedAt = try container.decodeIfPresent(Date.self, forKey: .lastUsedAt)
    copyCount = try container.decodeIfPresent(Int.self, forKey: .copyCount) ?? 1
  }
}
