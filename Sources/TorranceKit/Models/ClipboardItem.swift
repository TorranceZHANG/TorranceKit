import Foundation

struct ClipboardItem: Codable, Identifiable, Hashable {
  let id: UUID
  let text: String
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
    self.text = text
    self.createdAt = createdAt
    self.lastUsedAt = lastUsedAt
    self.copyCount = copyCount
  }
}
