import AppKit
import ApplicationServices
import Combine

@MainActor
final class AccessibilityPermission: ObservableObject {
  @Published private(set) var isTrusted = AXIsProcessTrusted()
  private var timer: Timer?

  init() {
    let timer = Timer(timeInterval: 1.5, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.refresh()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  deinit {
    timer?.invalidate()
  }

  func refresh() {
    isTrusted = AXIsProcessTrusted()
  }

  func request() {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [promptKey: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(options)
    refresh()
  }
}
