import Foundation

struct RetentionPolicy: Codable, Equatable {
  var maxItems: Int?
  var retentionDays: Int?

  static let `default` = RetentionPolicy(maxItems: 1_000, retentionDays: 30)

  func validated() throws -> RetentionPolicy {
    if let maxItems, maxItems < 1 {
      throw ConfigurationError.invalidValue("maxItems 必须是正整数或 null")
    }
    if let retentionDays, retentionDays < 1 {
      throw ConfigurationError.invalidValue("retentionDays 必须是正整数或 null")
    }
    return self
  }
}

enum HotKeyTriggerMode: String, Codable, CaseIterable {
  case keyCombination
  case doubleTapModifier
}

struct HotKeyConfiguration: Codable, Equatable {
  var mode: HotKeyTriggerMode
  var key: String
  var modifiers: [String]
  var doubleTapModifier: String
  var doubleTapIntervalMilliseconds: Int

  static let `default` = HotKeyConfiguration(key: "V", modifiers: ["option"])
  static let clipboardDefault = HotKeyConfiguration(
    mode: .doubleTapModifier, key: "V", modifiers: ["option"], doubleTapModifier: "control"
  )
  static let launcherDefault = HotKeyConfiguration(
    mode: .doubleTapModifier, key: "SPACE", modifiers: ["option"], doubleTapModifier: "command"
  )

  func conflicts(with other: HotKeyConfiguration) -> Bool {
    guard mode == other.mode else { return false }
    switch mode {
    case .doubleTapModifier:
      return doubleTapModifier.lowercased() == other.doubleTapModifier.lowercased()
    case .keyCombination:
      return key.uppercased() == other.key.uppercased()
        && Set(modifiers.map { $0.lowercased() }) == Set(other.modifiers.map { $0.lowercased() })
    }
  }

  init(
    mode: HotKeyTriggerMode = .keyCombination,
    key: String,
    modifiers: [String],
    doubleTapModifier: String = "control",
    doubleTapIntervalMilliseconds: Int = 400
  ) {
    self.mode = mode
    self.key = key
    self.modifiers = modifiers
    self.doubleTapModifier = doubleTapModifier
    self.doubleTapIntervalMilliseconds = doubleTapIntervalMilliseconds
  }

  var displayText: String {
    let symbols = ["control": "⌃", "option": "⌥", "shift": "⇧", "command": "⌘"]
    if mode == .doubleTapModifier {
      let names = [
        "control": "Ctrl", "option": "Option", "shift": "Shift", "command": "Command",
      ]
      let modifier = doubleTapModifier.lowercased()
      return "双击 \(symbols[modifier] ?? "")\(names[modifier] ?? modifier)"
    }
    let prefix = ["control", "option", "shift", "command"]
      .filter { modifiers.contains($0) }
      .compactMap { symbols[$0] }
      .joined()
    return prefix + key.uppercased()
  }

  func validated() throws -> HotKeyConfiguration {
    let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    let supportedSpecialKeys: Set<String> = ["SPACE", "RETURN", "TAB"]
    let isLetterOrNumber =
      normalizedKey.count == 1
      && normalizedKey.unicodeScalars.allSatisfy {
        CharacterSet.alphanumerics.contains($0) && $0.isASCII
      }
    guard isLetterOrNumber || supportedSpecialKeys.contains(normalizedKey) else {
      throw ConfigurationError.invalidValue(
        "hotKey.key 仅支持 A-Z、0-9、SPACE、RETURN 或 TAB"
      )
    }

    let allowedModifiers: Set<String> = ["command", "control", "option", "shift"]
    let normalizedModifiers = modifiers.map {
      $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    guard mode == .doubleTapModifier || !normalizedModifiers.isEmpty else {
      throw ConfigurationError.invalidValue("hotKey.modifiers 至少需要一个修饰键")
    }
    guard normalizedModifiers.allSatisfy(allowedModifiers.contains) else {
      throw ConfigurationError.invalidValue(
        "hotKey.modifiers 只支持 command、control、option、shift"
      )
    }
    guard Set(normalizedModifiers).count == normalizedModifiers.count else {
      throw ConfigurationError.invalidValue("hotKey.modifiers 不能包含重复值")
    }

    let normalizedDoubleTapModifier =
      doubleTapModifier
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .lowercased()
    guard allowedModifiers.contains(normalizedDoubleTapModifier) else {
      throw ConfigurationError.invalidValue(
        "hotKey.doubleTapModifier 只支持 command、control、option 或 shift"
      )
    }
    guard (200...800).contains(doubleTapIntervalMilliseconds) else {
      throw ConfigurationError.invalidValue(
        "hotKey.doubleTapIntervalMilliseconds 必须在 200 到 800 之间"
      )
    }
    return HotKeyConfiguration(
      mode: mode,
      key: normalizedKey,
      modifiers: normalizedModifiers,
      doubleTapModifier: normalizedDoubleTapModifier,
      doubleTapIntervalMilliseconds: doubleTapIntervalMilliseconds
    )
  }

  private enum CodingKeys: String, CodingKey {
    case mode, key, modifiers, doubleTapModifier, doubleTapIntervalMilliseconds
  }

  init(from decoder: Decoder) throws {
    let defaults = HotKeyConfiguration.default
    let container = try decoder.container(keyedBy: CodingKeys.self)
    mode = try container.decodeIfPresent(HotKeyTriggerMode.self, forKey: .mode) ?? defaults.mode
    key = try container.decodeIfPresent(String.self, forKey: .key) ?? defaults.key
    modifiers =
      try container.decodeIfPresent([String].self, forKey: .modifiers)
      ?? defaults.modifiers
    doubleTapModifier =
      try container.decodeIfPresent(
        String.self,
        forKey: .doubleTapModifier
      ) ?? defaults.doubleTapModifier
    doubleTapIntervalMilliseconds =
      try container.decodeIfPresent(
        Int.self,
        forKey: .doubleTapIntervalMilliseconds
      ) ?? defaults.doubleTapIntervalMilliseconds
  }
}

struct AppSettings: Codable, Equatable {
  var maxItems: Int?
  var retentionDays: Int?
  var hotKey: HotKeyConfiguration
  var capturesImages: Bool
  var maxTextBytes: Int
  var maxImageBytes: Int
  var pollIntervalMilliseconds: Int
  var autoPaste: Bool
  var pasteDelayMilliseconds: Int
  var excludedBundleIdentifiers: [String]
  var launcher: LauncherSettings

  static let `default` = AppSettings(
    maxItems: 1_000,
    retentionDays: 30,
    hotKey: .clipboardDefault,
    capturesImages: true,
    maxTextBytes: 1_048_576,
    maxImageBytes: 20_971_520,
    pollIntervalMilliseconds: 450,
    autoPaste: true,
    pasteDelayMilliseconds: 160,
    excludedBundleIdentifiers: []
  )

  var retentionPolicy: RetentionPolicy {
    RetentionPolicy(maxItems: maxItems, retentionDays: retentionDays)
  }

  func validated() throws -> AppSettings {
    _ = try retentionPolicy.validated()
    let hotKey = try hotKey.validated()
    let launcher = try launcher.validated()
    guard !hotKey.conflicts(with: launcher.hotKey) else {
      throw ConfigurationError.invalidValue("启动器和剪贴板不能使用相同的呼出方式")
    }
    guard (1_024...10_485_760).contains(maxTextBytes) else {
      throw ConfigurationError.invalidValue(
        "maxTextBytes 必须在 1024 到 10485760 之间"
      )
    }
    guard (65_536...52_428_800).contains(maxImageBytes) else {
      throw ConfigurationError.invalidValue(
        "maxImageBytes 必须在 65536 到 52428800 之间"
      )
    }
    guard (100...5_000).contains(pollIntervalMilliseconds) else {
      throw ConfigurationError.invalidValue(
        "pollIntervalMilliseconds 必须在 100 到 5000 之间"
      )
    }
    guard (50...2_000).contains(pasteDelayMilliseconds) else {
      throw ConfigurationError.invalidValue(
        "pasteDelayMilliseconds 必须在 50 到 2000 之间"
      )
    }
    guard excludedBundleIdentifiers.allSatisfy({ !$0.isEmpty }) else {
      throw ConfigurationError.invalidValue(
        "excludedBundleIdentifiers 不能包含空字符串"
      )
    }

    var result = self
    result.hotKey = hotKey
    result.launcher = launcher
    result.excludedBundleIdentifiers = Array(Set(excludedBundleIdentifiers)).sorted()
    return result
  }

  private enum CodingKeys: String, CodingKey {
    case maxItems, retentionDays, hotKey, capturesImages, maxTextBytes, maxImageBytes
    case pollIntervalMilliseconds, autoPaste, pasteDelayMilliseconds
    case excludedBundleIdentifiers
    case launcher
  }

  init(
    maxItems: Int?,
    retentionDays: Int?,
    hotKey: HotKeyConfiguration,
    capturesImages: Bool,
    maxTextBytes: Int,
    maxImageBytes: Int,
    pollIntervalMilliseconds: Int,
    autoPaste: Bool,
    pasteDelayMilliseconds: Int,
    excludedBundleIdentifiers: [String],
    launcher: LauncherSettings = .default
  ) {
    self.maxItems = maxItems
    self.retentionDays = retentionDays
    self.hotKey = hotKey
    self.capturesImages = capturesImages
    self.maxTextBytes = maxTextBytes
    self.maxImageBytes = maxImageBytes
    self.pollIntervalMilliseconds = pollIntervalMilliseconds
    self.autoPaste = autoPaste
    self.pasteDelayMilliseconds = pasteDelayMilliseconds
    self.excludedBundleIdentifiers = excludedBundleIdentifiers
    self.launcher = launcher
  }

  init(from decoder: Decoder) throws {
    let defaults = AppSettings.default
    let container = try decoder.container(keyedBy: CodingKeys.self)
    maxItems =
      container.contains(.maxItems)
      ? try container.decodeIfPresent(Int.self, forKey: .maxItems)
      : defaults.maxItems
    retentionDays =
      container.contains(.retentionDays)
      ? try container.decodeIfPresent(Int.self, forKey: .retentionDays)
      : defaults.retentionDays
    hotKey =
      try container.decodeIfPresent(HotKeyConfiguration.self, forKey: .hotKey)
      ?? HotKeyConfiguration.default
    launcher = try container.decodeIfPresent(LauncherSettings.self, forKey: .launcher)
      ?? defaults.launcher
    // Existing clipboard bindings take precedence when upgrading from 0.2.x.
    if !container.contains(.launcher), hotKey.conflicts(with: launcher.hotKey) {
      launcher.hotKey = HotKeyConfiguration(key: "SPACE", modifiers: ["control", "option"])
    }
    capturesImages =
      try container.decodeIfPresent(Bool.self, forKey: .capturesImages)
      ?? defaults.capturesImages
    maxTextBytes =
      try container.decodeIfPresent(Int.self, forKey: .maxTextBytes)
      ?? defaults.maxTextBytes
    maxImageBytes =
      try container.decodeIfPresent(Int.self, forKey: .maxImageBytes)
      ?? defaults.maxImageBytes
    pollIntervalMilliseconds =
      try container.decodeIfPresent(
        Int.self,
        forKey: .pollIntervalMilliseconds
      ) ?? defaults.pollIntervalMilliseconds
    autoPaste =
      try container.decodeIfPresent(Bool.self, forKey: .autoPaste)
      ?? defaults.autoPaste
    pasteDelayMilliseconds =
      try container.decodeIfPresent(
        Int.self,
        forKey: .pasteDelayMilliseconds
      ) ?? defaults.pasteDelayMilliseconds
    excludedBundleIdentifiers =
      try container.decodeIfPresent(
        [String].self,
        forKey: .excludedBundleIdentifiers
      ) ?? defaults.excludedBundleIdentifiers
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if let maxItems {
      try container.encode(maxItems, forKey: .maxItems)
    } else {
      try container.encodeNil(forKey: .maxItems)
    }
    if let retentionDays {
      try container.encode(retentionDays, forKey: .retentionDays)
    } else {
      try container.encodeNil(forKey: .retentionDays)
    }
    try container.encode(hotKey, forKey: .hotKey)
    try container.encode(capturesImages, forKey: .capturesImages)
    try container.encode(maxTextBytes, forKey: .maxTextBytes)
    try container.encode(maxImageBytes, forKey: .maxImageBytes)
    try container.encode(pollIntervalMilliseconds, forKey: .pollIntervalMilliseconds)
    try container.encode(autoPaste, forKey: .autoPaste)
    try container.encode(pasteDelayMilliseconds, forKey: .pasteDelayMilliseconds)
    try container.encode(excludedBundleIdentifiers, forKey: .excludedBundleIdentifiers)
    try container.encode(launcher, forKey: .launcher)
  }
}

enum ConfigurationError: LocalizedError {
  case invalidValue(String)

  var errorDescription: String? {
    switch self {
    case .invalidValue(let message):
      return message
    }
  }
}
