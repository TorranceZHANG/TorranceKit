import AppKit
import ApplicationServices

@MainActor
enum PasteController {
  static func copyAndPaste(
    text: String,
    into targetApplication: NSRunningApplication?,
    automatically: Bool,
    delayMilliseconds: Int
  ) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)

    targetApplication?.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    guard automatically else { return }

    let delay = TimeInterval(delayMilliseconds) / 1_000
    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
      guard let source = CGEventSource(stateID: .hidSystemState),
        let keyDown = CGEvent(
          keyboardEventSource: source,
          virtualKey: 0x09,
          keyDown: true
        ),
        let keyUp = CGEvent(
          keyboardEventSource: source,
          virtualKey: 0x09,
          keyDown: false
        )
      else {
        return
      }
      keyDown.flags = .maskCommand
      keyUp.flags = .maskCommand
      keyDown.post(tap: .cghidEventTap)
      keyUp.post(tap: .cghidEventTap)
    }
  }
}
