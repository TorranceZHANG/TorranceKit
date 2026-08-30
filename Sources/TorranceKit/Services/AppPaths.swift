import Foundation

enum AppPaths {
  static let currentApplicationName = "TorranceKit"
  static let legacyApplicationName = "PasteNook"

  nonisolated static var applicationSupportDirectoryURL: URL {
    applicationSupportBaseURL
      .appendingPathComponent(currentApplicationName, isDirectory: true)
  }

  nonisolated static var configurationURL: URL {
    applicationSupportDirectoryURL
      .appendingPathComponent("config.json", isDirectory: false)
  }

  nonisolated static var clipboardDirectoryURL: URL {
    applicationSupportDirectoryURL
      .appendingPathComponent("Clipboard", isDirectory: true)
  }

  nonisolated static var clipboardHistoryURL: URL {
    clipboardDirectoryURL
      .appendingPathComponent("history.json", isDirectory: false)
  }

  nonisolated static var legacyApplicationSupportDirectoryURL: URL {
    applicationSupportBaseURL
      .appendingPathComponent(legacyApplicationName, isDirectory: true)
  }

  static func migrateLegacyDataIfNeeded(fileManager: FileManager = .default) {
    do {
      try migrateLegacyData(
        from: legacyApplicationSupportDirectoryURL,
        to: applicationSupportDirectoryURL,
        fileManager: fileManager
      )
    } catch {
      NSLog("TorranceKit: failed to migrate PasteNook data: %@", error.localizedDescription)
    }
  }

  static func migrateLegacyData(
    from legacyDirectoryURL: URL,
    to currentDirectoryURL: URL,
    fileManager: FileManager = .default
  ) throws {
    guard fileManager.fileExists(atPath: legacyDirectoryURL.path) else { return }

    let clipboardDirectoryURL =
      currentDirectoryURL
      .appendingPathComponent("Clipboard", isDirectory: true)
    try createPrivateDirectory(currentDirectoryURL, fileManager: fileManager)
    try createPrivateDirectory(clipboardDirectoryURL, fileManager: fileManager)

    try copyIfNeeded(
      from: legacyDirectoryURL.appendingPathComponent("config.json"),
      to: currentDirectoryURL.appendingPathComponent("config.json"),
      fileManager: fileManager
    )
    try copyIfNeeded(
      from: legacyDirectoryURL.appendingPathComponent("history.json"),
      to: clipboardDirectoryURL.appendingPathComponent("history.json"),
      fileManager: fileManager
    )
  }

  private nonisolated static var applicationSupportBaseURL: URL {
    FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first
      ?? FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent("Library/Application Support", isDirectory: true)
  }

  private static func createPrivateDirectory(
    _ url: URL,
    fileManager: FileManager
  ) throws {
    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    try fileManager.setAttributes(
      [.posixPermissions: 0o700],
      ofItemAtPath: url.path
    )
  }

  private static func copyIfNeeded(
    from sourceURL: URL,
    to destinationURL: URL,
    fileManager: FileManager
  ) throws {
    guard fileManager.fileExists(atPath: sourceURL.path),
      !fileManager.fileExists(atPath: destinationURL.path)
    else {
      return
    }

    try fileManager.copyItem(at: sourceURL, to: destinationURL)
    try fileManager.setAttributes(
      [.posixPermissions: 0o600],
      ofItemAtPath: destinationURL.path
    )
  }
}
