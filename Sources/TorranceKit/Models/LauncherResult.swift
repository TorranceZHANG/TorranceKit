import Foundation

struct ApplicationEntry: Equatable, Sendable {
  let name: String
  let url: URL
  var abbreviation: String {
    name.filter { $0.isUppercase }.lowercased()
  }
}

enum LauncherAction: Equatable {
  case openApplication(URL)
  case openURL(URL)
  case copy(String)
  case clipboard
  case settings
  case none
}

struct LauncherResult: Identifiable, Equatable {
  let id: String
  let title: String
  let subtitle: String
  let symbol: String
  let action: LauncherAction
}

enum LauncherQueryEngine {
  private static let functionPrefixes = [
    "sqrt(", "abs(", "sin(", "cos(", "tan(", "log(", "ln(", "round(", "floor(", "ceil("
  ]
  static func results(
    query: String, applications: [ApplicationEntry], settings: LauncherSettings
  ) -> [LauncherResult] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let folded = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    var results: [LauncherResult] = []
    if trimmed.isEmpty || ["clipboard", "copy", "剪贴板", "粘贴板"].contains(folded) {
      results.append(LauncherResult(
        id: "clipboard", title: "剪贴板历史", subtitle: "打开文本和图片历史",
        symbol: "doc.on.clipboard", action: .clipboard
      ))
    }
    if trimmed.isEmpty || ["settings", "preferences", "设置"].contains(folded) {
      results.append(LauncherResult(
        id: "settings", title: "TorranceKit 设置", subtitle: "配置两个入口、搜索和剪贴板",
        symbol: "gearshape", action: .settings
      ))
    }
    if trimmed.isEmpty { return results }

    if settings.calculatorEnabled, looksLikeCalculation(trimmed) {
      do {
        let answer = try CalculatorEngine.evaluate(trimmed)
        results.append(LauncherResult(
          id: "calculator", title: answer, subtitle: "\(trimmed) · 回车复制结果",
          symbol: "equal.square", action: .copy(answer)
        ))
        if settings.webSearchEnabled { results.append(webResult(trimmed, engine: settings.searchEngine)) }
        return results
      } catch {
        if trimmed.hasPrefix("=")
          || functionPrefixes.contains(where: trimmed.lowercased().hasPrefix)
          || startsWithMathConstant(trimmed)
          || trimmed.allSatisfy({ $0.isNumber || $0.isWhitespace || "+-*/^().%eE".contains($0) }) {
          return [LauncherResult(
            id: "calculator-error", title: "暂时无法计算", subtitle: error.localizedDescription,
            symbol: "exclamationmark.circle", action: .none
          )]
        }
      }
    }

    if let url = websiteURL(trimmed) {
      results.insert(LauncherResult(
        id: "url", title: "打开 \(url.host ?? trimmed)", subtitle: url.absoluteString,
        symbol: "link", action: .openURL(url)
      ), at: 0)
      return results
    }

    let words = trimmed.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
    if settings.webSearchEnabled, words.count == 2,
       let engine = keywordEngine(String(words[0]).lowercased(), default: settings.searchEngine) {
      let term = String(words[1])
      return [webResult(term, engine: engine)]
    }

    if settings.searchesApplications {
      let matches = applications.compactMap { app -> (ApplicationEntry, Int)? in
        let name = app.name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if name == folded { return (app, 0) }
        if name.hasPrefix(folded) { return (app, 1) }
        if app.abbreviation == folded { return (app, 2) }
        if name.contains(folded) { return (app, 3) }
        return nil
      }.sorted {
        if $0.1 != $1.1 { return $0.1 < $1.1 }
        return $0.0.name.localizedStandardCompare($1.0.name) == .orderedAscending
      }
      results += matches.prefix(settings.maxResults).map { app, _ in
        LauncherResult(
          id: app.url.path, title: app.name, subtitle: app.url.deletingLastPathComponent().path,
          symbol: "app", action: .openApplication(app.url)
        )
      }
    }
    if settings.webSearchEnabled {
      // Reserve the last visible row for a deliberate web search.
      results = Array(results.prefix(max(0, settings.maxResults - 1)))
      results.append(webResult(trimmed, engine: settings.searchEngine))
    }
    return Array(results.prefix(settings.maxResults))
  }

  static func websiteURL(_ input: String) -> URL? {
    guard !input.contains(where: { $0.isWhitespace }) else { return nil }
    let explicitScheme = input.contains("://")
    let candidate = explicitScheme ? input : "https://" + input
    guard let components = URLComponents(string: candidate),
      ["http", "https"].contains(components.scheme?.lowercased() ?? ""),
      let host = components.host, !host.isEmpty,
      components.user == nil, components.password == nil
    else { return nil }
    if explicitScheme { return components.url }
    guard host.contains(".") || host == "localhost", !host.hasPrefix("."), !host.hasSuffix(".")
    else { return nil }
    if !host.contains(where: { $0.isLetter }) {
      let octets = host.split(separator: ".", omittingEmptySubsequences: false)
      guard octets.count == 4, octets.allSatisfy({ Int($0).map { (0...255).contains($0) } ?? false })
      else { return nil }
    } else if host != "localhost" {
      guard let lastLabel = host.split(separator: ".").last, lastLabel.count >= 2,
        lastLabel.first?.isLetter == true else { return nil }
    }
    return components.url
  }

  private static func looksLikeCalculation(_ text: String) -> Bool {
    if text.hasPrefix("=") { return true }
    guard let first = text.first else { return false }
    return first.isNumber || "+-(.".contains(first)
      || functionPrefixes.contains(where: text.lowercased().hasPrefix)
      || startsWithMathConstant(text)
  }

  private static func startsWithMathConstant(_ text: String) -> Bool {
    let lowercased = text.lowercased()
    for constant in ["pi", "e"] where lowercased.hasPrefix(constant) {
      let remainder = lowercased.dropFirst(constant.count).trimmingCharacters(in: .whitespaces)
      if remainder.isEmpty || remainder.first.map({ "+-*/^%".contains($0) }) == true { return true }
    }
    return false
  }

  private static func keywordEngine(_ keyword: String, default engine: WebSearchEngine) -> WebSearchEngine? {
    switch keyword {
    case "web", "search", "搜索": return engine
    case "google": return .google
    case "bing": return .bing
    case "ddg", "duckduckgo": return .duckduckgo
    case "baidu", "百度": return .baidu
    default: return nil
    }
  }

  private static func webResult(_ term: String, engine: WebSearchEngine) -> LauncherResult {
    LauncherResult(
      id: "web-\(engine.rawValue)", title: "用 \(engine.displayName) 搜索「\(term)」",
      subtitle: "回车后在默认浏览器中打开；输入期间不会联网",
      symbol: "globe", action: .openURL(engine.searchURL(for: term))
    )
  }
}
