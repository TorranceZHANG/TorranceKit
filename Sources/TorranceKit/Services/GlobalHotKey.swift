import AppKit
import Carbon.HIToolbox
import Foundation

struct ModifierDoubleTapDetector {
  let maximumInterval: TimeInterval

  private var isModifierPressed = false
  private var firstPressTimestamp: TimeInterval?
  private var wasReleasedAfterFirstPress = false

  init(maximumInterval: TimeInterval) {
    self.maximumInterval = maximumInterval
  }

  mutating func handle(
    isPressed: Bool,
    timestamp: TimeInterval,
    hasOtherStandardModifiers: Bool
  ) -> Bool {
    if hasOtherStandardModifiers {
      resetSequence()
      isModifierPressed = isPressed
      return false
    }

    guard isPressed != isModifierPressed else { return false }
    isModifierPressed = isPressed

    if isPressed {
      if let firstPressTimestamp,
        wasReleasedAfterFirstPress,
        timestamp - firstPressTimestamp <= maximumInterval
      {
        resetSequence()
        return true
      }

      firstPressTimestamp = timestamp
      wasReleasedAfterFirstPress = false
      return false
    }

    guard let firstPressTimestamp else { return false }
    if timestamp - firstPressTimestamp <= maximumInterval {
      wasReleasedAfterFirstPress = true
    } else {
      resetSequence()
    }
    return false
  }

  private mutating func resetSequence() {
    firstPressTimestamp = nil
    wasReleasedAfterFirstPress = false
  }
}

@MainActor
final class GlobalHotKey {
  var onPressed: (() -> Void)?
  private(set) var isRegistered = false

  private var hotKeyRef: EventHotKeyRef?
  private var eventHandlerRef: EventHandlerRef?
  private var globalModifierMonitor: Any?
  private var localModifierMonitor: Any?
  private var modifierFlag: NSEvent.ModifierFlags?
  private var doubleTapDetector: ModifierDoubleTapDetector?
  private let hotKeyID = EventHotKeyID(signature: 0x544B_5452, id: 1)  // TKTR
  private var configuration: HotKeyConfiguration

  init(configuration: HotKeyConfiguration) {
    self.configuration = configuration
    installCarbonHandler()
    do {
      try register(configuration)
    } catch {
      NSLog("TorranceKit: %@", error.localizedDescription)
    }
  }

  deinit {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
    }
    if let globalModifierMonitor {
      NSEvent.removeMonitor(globalModifierMonitor)
    }
    if let localModifierMonitor {
      NSEvent.removeMonitor(localModifierMonitor)
    }
    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
    }
  }

  func update(configuration newConfiguration: HotKeyConfiguration) throws {
    if newConfiguration == configuration, isRegistered { return }

    let oldConfiguration = configuration
    unregisterTrigger()

    do {
      try register(newConfiguration)
      configuration = newConfiguration
    } catch {
      try? register(oldConfiguration)
      throw error
    }
  }

  private func installCarbonHandler() {
    var eventType = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )

    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, event, userData -> OSStatus in
        guard let event, let userData else { return noErr }
        var pressedID = EventHotKeyID()
        let result = GetEventParameter(
          event,
          EventParamName(kEventParamDirectObject),
          EventParamType(typeEventHotKeyID),
          nil,
          MemoryLayout<EventHotKeyID>.size,
          nil,
          &pressedID
        )
        guard result == noErr else { return result }

        MainActor.assumeIsolated {
          let instance = Unmanaged<GlobalHotKey>
            .fromOpaque(userData)
            .takeUnretainedValue()
          if pressedID.signature == instance.hotKeyID.signature,
            pressedID.id == instance.hotKeyID.id
          {
            instance.onPressed?()
          }
        }
        return noErr
      },
      1,
      &eventType,
      Unmanaged.passUnretained(self).toOpaque(),
      &eventHandlerRef
    )

    if status != noErr {
      NSLog("TorranceKit: failed to install hot-key handler (%d)", status)
    }
  }

  private func register(_ configuration: HotKeyConfiguration) throws {
    switch configuration.mode {
    case .keyCombination:
      try registerKeyCombination(configuration)
    case .doubleTapModifier:
      try registerDoubleTapModifier(configuration)
    }
  }

  private func registerKeyCombination(_ configuration: HotKeyConfiguration) throws {
    guard let keyCode = Self.keyCodes[configuration.key.uppercased()] else {
      throw GlobalHotKeyError.unsupportedKey(configuration.key)
    }
    let modifiers = configuration.modifiers.reduce(UInt32(0)) { result, name in
      result | (Self.carbonModifierFlags[name] ?? 0)
    }
    let status = RegisterEventHotKey(
      keyCode,
      modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
    isRegistered = status == noErr
    if status != noErr {
      throw GlobalHotKeyError.registrationFailed(configuration.displayText, status)
    }
  }

  private func registerDoubleTapModifier(_ configuration: HotKeyConfiguration) throws {
    guard let modifierFlag = Self.eventModifierFlags[configuration.doubleTapModifier] else {
      throw GlobalHotKeyError.unsupportedModifier(configuration.doubleTapModifier)
    }

    self.modifierFlag = modifierFlag
    doubleTapDetector = ModifierDoubleTapDetector(
      maximumInterval: TimeInterval(configuration.doubleTapIntervalMilliseconds) / 1_000
    )

    globalModifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) {
      [weak self] event in
      DispatchQueue.main.async { [weak self] in
        self?.handleModifierEvent(event)
      }
    }
    localModifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) {
      [weak self] event in
      self?.handleModifierEvent(event)
      return event
    }

    isRegistered = globalModifierMonitor != nil && localModifierMonitor != nil
    if !isRegistered {
      unregisterTrigger()
      throw GlobalHotKeyError.monitorInstallationFailed
    }
  }

  private func handleModifierEvent(_ event: NSEvent) {
    guard let modifierFlag, var detector = doubleTapDetector else { return }
    let standardFlags = event.modifierFlags.intersection([
      .command, .control, .option, .shift,
    ])
    let isPressed = standardFlags.contains(modifierFlag)
    let otherFlagsRawValue = standardFlags.rawValue & ~modifierFlag.rawValue
    let shouldTrigger = detector.handle(
      isPressed: isPressed,
      timestamp: event.timestamp,
      hasOtherStandardModifiers: otherFlagsRawValue != 0
    )
    doubleTapDetector = detector
    if shouldTrigger {
      onPressed?()
    }
  }

  private func unregisterTrigger() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
    if let globalModifierMonitor {
      NSEvent.removeMonitor(globalModifierMonitor)
      self.globalModifierMonitor = nil
    }
    if let localModifierMonitor {
      NSEvent.removeMonitor(localModifierMonitor)
      self.localModifierMonitor = nil
    }
    modifierFlag = nil
    doubleTapDetector = nil
    isRegistered = false
  }

  private static let carbonModifierFlags: [String: UInt32] = [
    "command": UInt32(cmdKey),
    "control": UInt32(controlKey),
    "option": UInt32(optionKey),
    "shift": UInt32(shiftKey),
  ]

  private static let eventModifierFlags: [String: NSEvent.ModifierFlags] = [
    "command": .command,
    "control": .control,
    "option": .option,
    "shift": .shift,
  ]

  private static let keyCodes: [String: UInt32] = [
    "A": UInt32(kVK_ANSI_A), "B": UInt32(kVK_ANSI_B),
    "C": UInt32(kVK_ANSI_C), "D": UInt32(kVK_ANSI_D),
    "E": UInt32(kVK_ANSI_E), "F": UInt32(kVK_ANSI_F),
    "G": UInt32(kVK_ANSI_G), "H": UInt32(kVK_ANSI_H),
    "I": UInt32(kVK_ANSI_I), "J": UInt32(kVK_ANSI_J),
    "K": UInt32(kVK_ANSI_K), "L": UInt32(kVK_ANSI_L),
    "M": UInt32(kVK_ANSI_M), "N": UInt32(kVK_ANSI_N),
    "O": UInt32(kVK_ANSI_O), "P": UInt32(kVK_ANSI_P),
    "Q": UInt32(kVK_ANSI_Q), "R": UInt32(kVK_ANSI_R),
    "S": UInt32(kVK_ANSI_S), "T": UInt32(kVK_ANSI_T),
    "U": UInt32(kVK_ANSI_U), "V": UInt32(kVK_ANSI_V),
    "W": UInt32(kVK_ANSI_W), "X": UInt32(kVK_ANSI_X),
    "Y": UInt32(kVK_ANSI_Y), "Z": UInt32(kVK_ANSI_Z),
    "0": UInt32(kVK_ANSI_0), "1": UInt32(kVK_ANSI_1),
    "2": UInt32(kVK_ANSI_2), "3": UInt32(kVK_ANSI_3),
    "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5),
    "6": UInt32(kVK_ANSI_6), "7": UInt32(kVK_ANSI_7),
    "8": UInt32(kVK_ANSI_8), "9": UInt32(kVK_ANSI_9),
    "SPACE": UInt32(kVK_Space), "RETURN": UInt32(kVK_Return),
    "TAB": UInt32(kVK_Tab),
  ]
}

private enum GlobalHotKeyError: LocalizedError {
  case unsupportedKey(String)
  case unsupportedModifier(String)
  case registrationFailed(String, OSStatus)
  case monitorInstallationFailed

  var errorDescription: String? {
    switch self {
    case .unsupportedKey(let key):
      return "不支持快捷键按键：\(key)"
    case .unsupportedModifier(let modifier):
      return "不支持双击修饰键：\(modifier)"
    case .registrationFailed(let hotKey, let status):
      return "快捷键 \(hotKey) 注册失败（\(status)），可能已被其他应用占用"
    case .monitorInstallationFailed:
      return "无法安装双击修饰键监听器"
    }
  }
}
