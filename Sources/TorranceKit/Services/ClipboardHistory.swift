import Combine
import CryptoKit
import Foundation

@MainActor
final class ClipboardHistory: ObservableObject {
  @Published private(set) var items: [ClipboardItem] = []

  @Published private(set) var retentionPolicy: RetentionPolicy
  private let storageURL: URL
  private let imageDirectoryURL: URL
  private let fileManager: FileManager

  init(
    maxItems: Int? = RetentionPolicy.default.maxItems,
    retentionDays: Int? = RetentionPolicy.default.retentionDays,
    storageURL: URL = ClipboardHistory.defaultStorageURL,
    imageDirectoryURL: URL? = nil,
    fileManager: FileManager = .default
  ) {
    retentionPolicy = RetentionPolicy(
      maxItems: maxItems,
      retentionDays: retentionDays
    )
    self.storageURL = storageURL
    self.imageDirectoryURL =
      imageDirectoryURL
      ?? storageURL.deletingLastPathComponent()
      .appendingPathComponent("images", isDirectory: true)
    self.fileManager = fileManager
    load()
    prune()
  }

  func add(text: String, at date: Date = Date()) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }

    if let existingIndex = items.firstIndex(where: { $0.kind == .text && $0.text == text }) {
      var existing = items.remove(at: existingIndex)
      existing.copyCount += 1
      existing.createdAt = date
      items.insert(existing, at: 0)
    } else {
      items.insert(ClipboardItem(text: text, createdAt: date), at: 0)
    }

    prune(referenceDate: date)
  }

  @discardableResult
  func add(
    imagePNGData: Data,
    pixelWidth: Int,
    pixelHeight: Int,
    at date: Date = Date()
  ) -> Bool {
    guard !imagePNGData.isEmpty, pixelWidth > 0, pixelHeight > 0 else { return false }

    let digest = Self.sha256(imagePNGData)
    if let existingIndex = items.firstIndex(where: {
      $0.kind == .image && $0.imageDigest == digest
    }) {
      var existing = items.remove(at: existingIndex)
      if imageData(for: existing) == nil {
        guard
          let fileName = existing.imageFileName,
          writeImageData(imagePNGData, fileName: fileName)
        else {
          items.insert(existing, at: existingIndex)
          return false
        }
      }
      existing.copyCount += 1
      existing.createdAt = date
      items.insert(existing, at: 0)
    } else {
      let id = UUID()
      let fileName = "\(id.uuidString.lowercased()).png"
      guard writeImageData(imagePNGData, fileName: fileName) else { return false }
      items.insert(
        ClipboardItem(
          id: id,
          imageFileName: fileName,
          imageDigest: digest,
          imagePixelWidth: pixelWidth,
          imagePixelHeight: pixelHeight,
          imageByteCount: imagePNGData.count,
          createdAt: date
        ),
        at: 0
      )
    }

    prune(referenceDate: date)
    return true
  }

  func payload(for item: ClipboardItem) -> ClipboardPayload? {
    switch item.kind {
    case .text:
      return .text(item.text)
    case .image:
      guard let data = imageData(for: item) else { return nil }
      return .image(pngData: data)
    }
  }

  func imageData(for item: ClipboardItem) -> Data? {
    guard let url = imageFileURL(for: item) else { return nil }
    return try? Data(contentsOf: url, options: .mappedIfSafe)
  }

  func imageFileURL(for item: ClipboardItem) -> URL? {
    guard item.kind == .image, let fileName = item.imageFileName else { return nil }
    return imageURL(fileName: fileName)
  }

  func markUsed(_ item: ClipboardItem, at date: Date = Date()) {
    guard let index = items.firstIndex(where: { $0.id == item.id }) else {
      return
    }
    var usedItem = items.remove(at: index)
    usedItem.lastUsedAt = date
    items.insert(usedItem, at: 0)
    save()
  }

  func remove(_ item: ClipboardItem) {
    let removedItems = items.filter { $0.id == item.id }
    items.removeAll { $0.id == item.id }
    deleteImages(for: removedItems)
    save()
  }

  func clear() {
    let removedItems = items
    items.removeAll()
    deleteImages(for: removedItems)
    save()
  }

  func applyRetentionPolicy(_ policy: RetentionPolicy, at date: Date = Date()) {
    retentionPolicy = policy
    prune(referenceDate: date)
  }

  func prune(referenceDate: Date = Date()) {
    let originalItems = items

    if let retentionDays = retentionPolicy.retentionDays,
      let cutoff = Calendar.current.date(
        byAdding: .day,
        value: -retentionDays,
        to: referenceDate
      )
    {
      items.removeAll { item in
        max(item.createdAt, item.lastUsedAt ?? .distantPast) < cutoff
      }
    }

    if let maxItems = retentionPolicy.maxItems, items.count > maxItems {
      items.removeLast(items.count - maxItems)
    }

    let retainedIDs = Set(items.map(\.id))
    deleteImages(for: originalItems.filter { !retainedIDs.contains($0.id) })
    save()
  }

  private func load() {
    guard let data = try? Data(contentsOf: storageURL) else {
      return
    }

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    guard let decoded = try? decoder.decode([ClipboardItem].self, from: data) else {
      return
    }
    items = decoded.filter { item in
      switch item.kind {
      case .text:
        return true
      case .image:
        guard let fileName = item.imageFileName,
          let url = imageURL(fileName: fileName)
        else {
          return false
        }
        return fileManager.fileExists(atPath: url.path)
      }
    }
  }

  private func save() {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    do {
      let directoryURL = storageURL.deletingLastPathComponent()
      try createPrivateDirectory(directoryURL)
      let data = try encoder.encode(items)
      try data.write(to: storageURL, options: .atomic)
      try fileManager.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: storageURL.path
      )
    } catch {
      NSLog("TorranceKit: failed to save clipboard history: %@", error.localizedDescription)
    }
  }

  private func writeImageData(_ data: Data, fileName: String) -> Bool {
    guard let url = imageURL(fileName: fileName) else { return false }
    do {
      try createPrivateDirectory(imageDirectoryURL)
      try data.write(to: url, options: .atomic)
      try fileManager.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: url.path
      )
      return true
    } catch {
      NSLog("TorranceKit: failed to save clipboard image: %@", error.localizedDescription)
      return false
    }
  }

  private func deleteImages(for items: [ClipboardItem]) {
    for item in items where item.kind == .image {
      guard let fileName = item.imageFileName,
        let url = imageURL(fileName: fileName),
        fileManager.fileExists(atPath: url.path)
      else {
        continue
      }
      do {
        try fileManager.removeItem(at: url)
      } catch {
        NSLog("TorranceKit: failed to delete clipboard image: %@", error.localizedDescription)
      }
    }
  }

  private func createPrivateDirectory(_ url: URL) throws {
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    try fileManager.setAttributes(
      [.posixPermissions: 0o700],
      ofItemAtPath: url.path
    )
  }

  private func imageURL(fileName: String) -> URL? {
    guard !fileName.isEmpty,
      fileName == (fileName as NSString).lastPathComponent,
      fileName.lowercased().hasSuffix(".png")
    else {
      return nil
    }
    return imageDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
  }

  private static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  nonisolated static var defaultStorageURL: URL {
    AppPaths.clipboardHistoryURL
  }
}
