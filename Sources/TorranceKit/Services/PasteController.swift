import AppKit
import ApplicationServices

@MainActor
enum PasteController {
  static func copyAndPaste(
    payload: ClipboardPayload,
    into targetApplication: NSRunningApplication?,
    automatically: Bool,
    delayMilliseconds: Int
  ) {
    let pasteboard = NSPasteboard.general
    write(payload, to: pasteboard)

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

  @discardableResult
  static func write(_ payload: ClipboardPayload, to pasteboard: NSPasteboard) -> Bool {
    pasteboard.clearContents()
    switch payload {
    case .text(let text):
      return pasteboard.setString(text, forType: .string)
    case .image(let pngData):
      let wrotePNG = pasteboard.setData(pngData, forType: .png)
      if let tiffData = NSImage(data: pngData)?.tiffRepresentation {
        pasteboard.setData(tiffData, forType: .tiff)
      }
      return wrotePNG
    }
  }
}
