import Combine
import Foundation

@MainActor
final class ClipboardHistory: ObservableObject {
  @Published private(set) var items: [ClipboardItem] = []

  @Published private(set) var retentionPolicy: RetentionPolicy
  private let storageURL: URL

  init(
    maxItems: Int? = RetentionPolicy.default.maxItems,
    retentionDays: Int? = RetentionPolicy.default.retentionDays,
    storageURL: URL = ClipboardHistory.defaultStorageURL
  ) {
    retentionPolicy = RetentionPolicy(
      maxItems: maxItems,
      retentionDays: retentionDays
    )
    self.storageURL = storageURL
    load()
    prune()
  }

  func add(text: String, at date: Date = Date()) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }

    if let existingIndex = items.firstIndex(where: { $0.text == text }) {
      var existing = items.remove(at: existingIndex)
      existing.copyCount += 1
      existing.createdAt = date
      items.insert(existing, at: 0)
    } else {
      items.insert(ClipboardItem(text: text, createdAt: date), at: 0)
    }

    prune(referenceDate: date)
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
    items.removeAll { $0.id == item.id }
    save()
  }

  func clear() {
    items.removeAll()
    save()
  }

  func applyRetentionPolicy(_ policy: RetentionPolicy, at date: Date = Date()) {
    retentionPolicy = policy
    prune(referenceDate: date)
  }

  func prune(referenceDate: Date = Date()) {
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
    items = decoded
  }

  private func save() {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoder.dateEncodingStrategy = .iso8601

    do {
      let directoryURL = storageURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
      )
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: directoryURL.path
      )
      let data = try encoder.encode(items)
      try data.write(to: storageURL, options: .atomic)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: storageURL.path
      )
    } catch {
      NSLog("TorranceKit: failed to save clipboard history: %@", error.localizedDescription)
    }
  }

  nonisolated static var defaultStorageURL: URL {
    AppPaths.clipboardHistoryURL
  }
}
