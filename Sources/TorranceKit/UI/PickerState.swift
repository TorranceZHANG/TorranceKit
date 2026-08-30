import Combine
import Foundation

@MainActor
final class PickerState: ObservableObject {
  @Published var query = ""
  @Published var selectedIndex = 0

  func reset() {
    query = ""
    selectedIndex = 0
  }

  func filteredItems(from items: [ClipboardItem]) -> [ClipboardItem] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return items }
    return items.filter { item in
      item.text.localizedCaseInsensitiveContains(needle)
    }
  }

  func moveSelection(by delta: Int, itemCount: Int) {
    guard itemCount > 0 else {
      selectedIndex = 0
      return
    }
    selectedIndex = min(max(selectedIndex + delta, 0), itemCount - 1)
  }

  func normalizeSelection(itemCount: Int) {
    guard itemCount > 0 else {
      selectedIndex = 0
      return
    }
    selectedIndex = min(selectedIndex, itemCount - 1)
  }
}
