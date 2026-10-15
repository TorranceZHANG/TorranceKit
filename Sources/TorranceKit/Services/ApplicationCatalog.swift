import Foundation

enum ApplicationCatalog {
  static func load(in directories: [URL] = defaultDirectories) -> [ApplicationEntry] {
    let manager = FileManager.default
    var seen: Set<String> = []
    var entries: [ApplicationEntry] = []
    for directory in directories {
      guard let enumerator = manager.enumerator(
        at: directory, includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles, .skipsPackageDescendants]
      ) else { continue }
      for case let url as URL in enumerator {
        guard !Task<Never, Never>.isCancelled else { return entries }
        guard url.pathExtension.lowercased() == "app" else { continue }
        enumerator.skipDescendants()
        let path = url.resolvingSymlinksInPath().path
        guard seen.insert(path).inserted else { continue }
        let bundle = Bundle(url: url)
        let name = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
          ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
          ?? url.deletingPathExtension().lastPathComponent
        entries.append(ApplicationEntry(name: name, url: url))
        if entries.count >= 3_000 { return entries }
      }
    }
    return entries
  }

  static var defaultDirectories: [URL] {
    ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"]
      .map { URL(fileURLWithPath: $0, isDirectory: true) }
  }
}
