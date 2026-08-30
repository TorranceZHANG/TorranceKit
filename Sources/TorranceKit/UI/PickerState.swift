import Combine
import Foundation

@MainActor
final class PickerState: ObservableObject {
  @Published var query = ""
  @Published var selectedIndex = 0
  @Published private(set) var selectionScrollRequest = 0

  func reset() {
    query = ""
    selectedIndex = 0
    requestSelectionScroll()
  }

  func selectFirstAndRequestScroll() {
    selectedIndex = 0
    requestSelectionScroll()
  }

  func filteredItems(from items: [ClipboardItem]) -> [ClipboardItem] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !needle.isEmpty else { return items }
    return items.filter { item in
      item.searchableText.localizedCaseInsensitiveContains(needle)
    }
  }

  func select(index: Int, itemCount: Int) {
    guard itemCount > 0 else {
      selectedIndex = 0
      return
    }
    selectedIndex = min(max(index, 0), itemCount - 1)
  }

  func moveSelection(by delta: Int, itemCount: Int) {
    guard itemCount > 0 else {
      selectedIndex = 0
      return
    }
    selectedIndex = min(max(selectedIndex + delta, 0), itemCount - 1)
    requestSelectionScroll()
  }

  func normalizeSelection(itemCount: Int) {
    guard itemCount > 0 else {
      selectedIndex = 0
      return
    }
    selectedIndex = min(selectedIndex, itemCount - 1)
  }

  private func requestSelectionScroll() {
    selectionScrollRequest &+= 1
  }
}
