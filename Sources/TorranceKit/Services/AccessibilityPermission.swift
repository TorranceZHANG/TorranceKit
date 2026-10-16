import AppKit
import ApplicationServices
import Combine

@MainActor
final class AccessibilityPermission: ObservableObject {
  @Published private(set) var isTrusted = false
  var onWillRequest: (() -> Void)?
  private let checkTrust: () -> Bool
  private let prompt: () -> Void
  private let openSettings: () -> Void
  private var timer: Timer?

  init(
    checkTrust: @escaping () -> Bool = { AXIsProcessTrusted() },
    prompt: @escaping () -> Void = {
      let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
      _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    },
    openSettings: @escaping () -> Void = {
      if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
        NSWorkspace.shared.open(url)
      }
    }
  ) {
    self.checkTrust = checkTrust
    self.prompt = prompt
    self.openSettings = openSettings
  }

  func startMonitoring() {
    refresh()
    guard timer == nil else { return }
    let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.refresh()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  func stopMonitoring() {
    timer?.invalidate()
    timer = nil
  }

  deinit {
    timer?.invalidate()
  }

  func refresh() {
    let trusted = checkTrust()
    if trusted != isTrusted { isTrusted = trusted }
  }

  func request() {
    // A view can still contain the old button when returning from System Settings.
    // Never prompt again if the current process has already been granted access.
    refresh()
    guard !isTrusted else { return }
    onWillRequest?()
    prompt()
    openSettings()
    refresh()
  }
}
