import AppKit
import Combine
import Foundation

@MainActor
final class AppConfiguration: ObservableObject {
  @Published private(set) var settings: AppSettings
  let fileURL: URL

  init(fileURL: URL = AppConfiguration.defaultURL) {
    self.fileURL = fileURL
    settings = .default
    createDefaultFileIfNeeded()
    hardenPermissions()
    if let loaded = try? Self.read(from: fileURL) {
      settings = loaded
    }
  }

  func readFromDisk() throws -> AppSettings {
    try Self.read(from: fileURL)
  }

  func writeToDisk(_ newSettings: AppSettings) throws {
    let validatedSettings = try newSettings.validated()
    let directoryURL = fileURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(validatedSettings)
    try data.write(to: fileURL, options: .atomic)
    hardenPermissions()
  }

  func apply(_ newSettings: AppSettings) {
    settings = newSettings
  }

  func openInDefaultEditor() {
    createDefaultFileIfNeeded()
    hardenPermissions()
    NSWorkspace.shared.open(fileURL)
  }

  func revealInFinder() {
    createDefaultFileIfNeeded()
    hardenPermissions()
    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
  }

  private func hardenPermissions() {
    let directoryURL = fileURL.deletingLastPathComponent()
    try? FileManager.default.setAttributes(
      [.posixPermissions: 0o700],
      ofItemAtPath: directoryURL.path
    )
    try? FileManager.default.setAttributes(
      [.posixPermissions: 0o600],
      ofItemAtPath: fileURL.path
    )
  }

  private func createDefaultFileIfNeeded() {
    guard !FileManager.default.fileExists(atPath: fileURL.path) else { return }
    do {
      let directoryURL = fileURL.deletingLastPathComponent()
      try FileManager.default.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true
      )
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o700],
        ofItemAtPath: directoryURL.path
      )
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
      let data = try encoder.encode(AppSettings.default)
      try data.write(to: fileURL, options: .atomic)
      try FileManager.default.setAttributes(
        [.posixPermissions: 0o600],
        ofItemAtPath: fileURL.path
      )
    } catch {
      NSLog("TorranceKit: failed to create config file: %@", error.localizedDescription)
    }
  }

  private static func read(from url: URL) throws -> AppSettings {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(AppSettings.self, from: data).validated()
  }

  nonisolated static var defaultURL: URL {
    AppPaths.configurationURL
  }
}
