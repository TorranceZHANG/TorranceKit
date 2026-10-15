import AppKit
import SwiftUI

@MainActor
final class LauncherPanelController: NSObject, NSWindowDelegate {
  let model = LauncherModel()
  private let configuration: AppConfiguration
  private let onExecute: (LauncherAction) -> Void
  private let onSettings: () -> Void
  private let onInput: () -> Void
  private var panel: LauncherPanel!
  private var keyboardMonitor: Any?
  private var observers: [NSObjectProtocol] = []
  private var targetApplication: NSRunningApplication?
  var isVisible: Bool { panel.isVisible }

  init(
    configuration: AppConfiguration, permission: AccessibilityPermission,
    onInput: @escaping () -> Void,
    onSettings: @escaping () -> Void, onExecute: @escaping (LauncherAction) -> Void
  ) {
    self.configuration = configuration
    self.onSettings = onSettings
    self.onInput = onInput
    self.onExecute = onExecute
    super.init()
    panel = LauncherPanel(
      contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
      styleMask: PickerPanelController.styleMask, backing: .buffered, defer: false
    )
    panel.delegate = self
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.becomesKeyOnlyIfNeeded = false
    panel.collectionBehavior = PickerPanelController.collectionBehavior
    panel.isMovableByWindowBackground = false
    panel.contentView = NSHostingView(rootView: LauncherView(
      model: model, configuration: configuration, permission: permission,
      onExecute: { [weak self] result in self?.choose(result) },
      onClose: { [weak self] in self?.hide() },
      onSettings: { [weak self] in self?.openSettings() }
    ))
    let center = NSWorkspace.shared.notificationCenter
    for notification in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.didActivateApplicationNotification] {
      observers.append(center.addObserver(forName: notification, object: nil, queue: .main) { [weak self] note in
        MainActor.assumeIsolated {
          if notification == NSWorkspace.didActivateApplicationNotification,
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            app.processIdentifier == ProcessInfo.processInfo.processIdentifier { return }
          self?.hide()
        }
      })
    }
  }

  deinit {
    if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) }
    for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
  }

  func show() {
    let current = NSWorkspace.shared.frontmostApplication
    if current?.processIdentifier != ProcessInfo.processInfo.processIdentifier {
      targetApplication = current
    }
    model.show(settings: configuration.settings.launcher)
    position()
    removeKeyboardMonitor()
    keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      let consumed = MainActor.assumeIsolated {
        guard let self, event.window === self.panel, self.panel.isKeyWindow else { return false }
        self.onInput()
        // Leave Return/arrows to the input method while composing Chinese/Japanese text.
        if let editor = self.panel.firstResponder as? NSTextView, editor.hasMarkedText() { return false }
        switch event.keyCode {
        case 53: self.hide(); return true
        case 125: self.model.moveSelection(by: 1); return true
        case 126: self.model.moveSelection(by: -1); return true
        case 36, 76:
          if let result = self.model.selectedResult { self.choose(result) }
          return true
        case 43 where event.modifierFlags.contains(.command): self.openSettings(); return true
        default: return false
        }
      }
      return consumed ? nil : event
    }
    NSApp.activate(ignoringOtherApps: true)
    panel.makeKeyAndOrderFront(nil)
  }

  func hide() {
    panel.orderOut(nil)
    removeKeyboardMonitor()
    model.hide()
  }

  func windowDidResignKey(_ notification: Notification) { hide() }

  private func choose(_ result: LauncherResult) {
    guard result.action != .none else { return }
    hide()
    onExecute(result.action)
    if case .copy = result.action, targetApplication?.isTerminated == false {
      targetApplication?.activate(options: [.activateIgnoringOtherApps])
    }
  }

  private func openSettings() {
    hide()
    onSettings()
  }

  private func removeKeyboardMonitor() {
    if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) }
    keyboardMonitor = nil
  }

  private func position() {
    let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
      ?? NSScreen.main
    guard let frame = screen?.visibleFrame else { panel.center(); return }
    panel.setFrameOrigin(NSPoint(
      x: frame.midX - panel.frame.width / 2,
      y: max(frame.minY, frame.midY - panel.frame.height / 2 + 80)
    ))
  }
}

private final class LauncherPanel: NSPanel {
  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }
}
