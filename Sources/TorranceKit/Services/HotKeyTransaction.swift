import Foundation

/// Both bindings are replaced together, including swaps, before persisting configuration.
enum HotKeyTransaction {
  static func apply<Settings>(
    previous: Settings, candidate: Settings,
    unregister: () -> Void, register: (Settings) throws -> Void,
    persist: () throws -> Void
  ) throws {
    unregister()
    do {
      try register(candidate)
      try persist()
    } catch {
      let originalError = error
      unregister()
      do {
        try register(previous)
      } catch {
        throw ConfigurationError.invalidValue(
          "更新失败：\(originalError.localizedDescription)；恢复原快捷键失败：\(error.localizedDescription)。请重新打开设置调整快捷键。"
        )
      }
      throw originalError
    }
  }
}
