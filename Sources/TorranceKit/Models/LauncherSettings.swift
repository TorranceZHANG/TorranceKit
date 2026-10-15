import Foundation

enum WebSearchEngine: String, Codable, CaseIterable {
  case google, bing, duckduckgo, baidu

  var displayName: String {
    switch self {
    case .google: return "Google"
    case .bing: return "Bing"
    case .duckduckgo: return "DuckDuckGo"
    case .baidu: return "百度"
    }
  }

  func searchURL(for query: String) -> URL {
    let base: String
    let parameter: String
    switch self {
    case .google: base = "https://www.google.com/search"; parameter = "q"
    case .bing: base = "https://www.bing.com/search"; parameter = "q"
    case .duckduckgo: base = "https://duckduckgo.com/"; parameter = "q"
    case .baidu: base = "https://www.baidu.com/s"; parameter = "wd"
    }
    var components = URLComponents(string: base)!
    components.queryItems = [URLQueryItem(name: parameter, value: query)]
    // Search engines decode query strings as form data, where an unescaped + is a space.
    components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
    return components.url!
  }
}

struct LauncherSettings: Codable, Equatable {
  var hotKey: HotKeyConfiguration
  var searchesApplications: Bool
  var calculatorEnabled: Bool
  var webSearchEnabled: Bool
  var searchEngine: WebSearchEngine
  var maxResults: Int

  static let `default` = LauncherSettings(
    hotKey: .launcherDefault, searchesApplications: true, calculatorEnabled: true,
    webSearchEnabled: true, searchEngine: .google, maxResults: 8
  )

  init(
    hotKey: HotKeyConfiguration, searchesApplications: Bool, calculatorEnabled: Bool,
    webSearchEnabled: Bool, searchEngine: WebSearchEngine, maxResults: Int
  ) {
    self.hotKey = hotKey
    self.searchesApplications = searchesApplications
    self.calculatorEnabled = calculatorEnabled
    self.webSearchEnabled = webSearchEnabled
    self.searchEngine = searchEngine
    self.maxResults = maxResults
  }

  func validated() throws -> LauncherSettings {
    guard (3...20).contains(maxResults) else {
      throw ConfigurationError.invalidValue("启动器结果数量必须在 3 到 20 之间")
    }
    var result = self
    result.hotKey = try hotKey.validated()
    return result
  }

  private enum CodingKeys: String, CodingKey {
    case hotKey, searchesApplications, calculatorEnabled, webSearchEnabled, searchEngine, maxResults
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = Self.default
    hotKey = try container.decodeIfPresent(HotKeyConfiguration.self, forKey: .hotKey) ?? defaults.hotKey
    searchesApplications = try container.decodeIfPresent(Bool.self, forKey: .searchesApplications)
      ?? defaults.searchesApplications
    calculatorEnabled = try container.decodeIfPresent(Bool.self, forKey: .calculatorEnabled)
      ?? defaults.calculatorEnabled
    webSearchEnabled = try container.decodeIfPresent(Bool.self, forKey: .webSearchEnabled)
      ?? defaults.webSearchEnabled
    searchEngine = try container.decodeIfPresent(WebSearchEngine.self, forKey: .searchEngine)
      ?? defaults.searchEngine
    maxResults = try container.decodeIfPresent(Int.self, forKey: .maxResults) ?? defaults.maxResults
  }
}
