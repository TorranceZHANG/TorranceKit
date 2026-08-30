import AppKit
import SwiftUI

@MainActor
final class PickerPanelController: NSObject, NSWindowDelegate {
  private let history: ClipboardHistory
  private let state = PickerState()
  private let onSelect: (ClipboardItem, NSRunningApplication?) -> Void
  private var panel: PickerPanel!
  private var keyboardMonitor: Any?
  private var targetApplication: NSRunningApplication?

  init(
    history: ClipboardHistory,
    permission: AccessibilityPermission,
    configuration: AppConfiguration,
    onSelect: @escaping (ClipboardItem, NSRunningApplication?) -> Void
  ) {
    self.history = history
    self.onSelect = onSelect
    super.init()

    let panel = PickerPanel(
      contentRect: NSRect(x: 0, y: 0, width: 680, height: 500),
      styleMask: [.borderless, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    panel.delegate = self
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isMovableByWindowBackground = true

    let view = PickerView(
      history: history,
      permission: permission,
      configuration: configuration,
      state: state,
      onSelect: { [weak self] item in self?.choose(item) },
      onDelete: { item in history.remove(item) },
      onClose: { [weak self] in self?.hide() }
    )
    let hostingView = NSHostingView(rootView: view)
    hostingView.wantsLayer = true
    hostingView.layer?.cornerRadius = 18
    hostingView.layer?.masksToBounds = true
    panel.contentView = hostingView
    self.panel = panel
  }

  deinit {
    if let keyboardMonitor {
      NSEvent.removeMonitor(keyboardMonitor)
    }
  }

  func show() {
    if panel.isVisible {
      panel.makeKeyAndOrderFront(nil)
      return
    }

    let currentApplication = NSWorkspace.shared.frontmostApplication
    if currentApplication?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
      targetApplication = currentApplication
    } else {
      targetApplication = nil
    }

    state.reset()
    positionPanel()
    installKeyboardMonitor()
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
  }

  func toggle() {
    panel.isVisible ? hide() : show()
  }

  func hide() {
    panel.orderOut(nil)
    removeKeyboardMonitor()
  }

  func windowDidResignKey(_ notification: Notification) {
    hide()
  }

  private func choose(_ item: ClipboardItem) {
    let target = targetApplication
    hide()
    onSelect(item, target)
  }

  private func positionPanel() {
    let screen = NSScreen.main ?? NSScreen.screens.first
    guard let visibleFrame = screen?.visibleFrame else {
      panel.center()
      return
    }
    let size = panel.frame.size
    let origin = NSPoint(
      x: visibleFrame.midX - size.width / 2,
      y: visibleFrame.maxY - size.height - 76
    )
    panel.setFrameOrigin(origin)
  }

  private func installKeyboardMonitor() {
    removeKeyboardMonitor()
    keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
      [weak self] event in
      let shouldConsume = MainActor.assumeIsolated {
        guard let self, self.panel.isKeyWindow else { return false }
        return self.handle(event)
      }
      return shouldConsume ? nil : event
    }
  }

  private func removeKeyboardMonitor() {
    if let keyboardMonitor {
      NSEvent.removeMonitor(keyboardMonitor)
      self.keyboardMonitor = nil
    }
  }

  private func handle(_ event: NSEvent) -> Bool {
    let items = state.filteredItems(from: history.items)
    switch event.keyCode {
    case 53:  // Escape
      hide()
      return true
    case 126:  // Up arrow
      state.moveSelection(by: -1, itemCount: items.count)
      return true
    case 125:  // Down arrow
      state.moveSelection(by: 1, itemCount: items.count)
      return true
    case 36, 76:  // Return / keypad Enter
      state.normalizeSelection(itemCount: items.count)
      guard items.indices.contains(state.selectedIndex) else { return true }
      choose(items[state.selectedIndex])
      return true
    default:
      break
    }

    let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard modifiers.contains(.command),
      let index = Self.numberKeyIndex[event.keyCode],
      items.indices.contains(index)
    else {
      return false
    }
    choose(items[index])
    return true
  }

  private static let numberKeyIndex: [UInt16: Int] = [
    18: 0, 19: 1, 20: 2, 21: 3, 23: 4,
    22: 5, 26: 6, 28: 7, 25: 8,
  ]
}

private final class PickerPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}
