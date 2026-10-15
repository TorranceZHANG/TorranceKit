import Foundation

enum CalculatorEngine {
  private static let maximumCharacterCount = 1_024
  private static let maximumUTF8ByteCount = maximumCharacterCount * 4

  static func evaluate(_ expression: String) throws -> String {
    // Checking a bounded UTF-8 prefix first also protects the Character count below
    // from pathological inputs containing one extremely large grapheme cluster.
    guard expression.utf8.prefix(maximumUTF8ByteCount + 1).count <= maximumUTF8ByteCount,
      expression.prefix(maximumCharacterCount + 1).count <= maximumCharacterCount
    else {
      throw EvaluationError.inputTooLong
    }

    var parser = Parser(expression)
    let value = try parser.parse()
    return format(value)
  }

  private static func format(_ value: Double) -> String {
    if value == 0 {
      return "0"
    }
    return String(
      format: "%.16g",
      locale: Locale(identifier: "en_US_POSIX"),
      value
    )
  }

  enum EvaluationError: LocalizedError, Equatable {
    case inputTooLong
    case emptyExpression
    case expressionTooDeep
    case incompleteExpression
    case invalidExpression(String)
    case unknownIdentifier(String)
    case missingClosingParenthesis
    case divisionByZero
    case nonFiniteResult

    var errorDescription: String? {
      switch self {
      case .inputTooLong:
        return "表达式过长，最多允许 1024 个字符。"
      case .emptyExpression:
        return "请输入要计算的表达式。"
      case .expressionTooDeep:
        return "表达式嵌套过深，最多允许 64 层。"
      case .incompleteExpression:
        return "表达式不完整，请补全数字、函数参数或右括号。"
      case .invalidExpression(let detail):
        return "表达式无效：\(detail)"
      case .unknownIdentifier(let identifier):
        return "无法识别的函数或常量：\(identifier)"
      case .missingClosingParenthesis:
        return "表达式不完整：缺少右括号。"
      case .divisionByZero:
        return "不能除以零。"
      case .nonFiniteResult:
        return "计算结果不是有限数值，请检查函数定义域或数值范围。"
      }
    }
  }
}

private extension CalculatorEngine {
  struct Parser {
    private static let maximumDepth = 64

    private let characters: [Character]
    private var index = 0

    init(_ expression: String) {
      characters = Array(expression)
    }

    mutating func parse() throws -> Double {
      skipWhitespace()
      _ = consume("=")
      skipWhitespace()
      guard !isAtEnd else {
        throw EvaluationError.emptyExpression
      }

      let value = try parseExpression(depth: 0)
      skipWhitespace()
      guard isAtEnd else {
        throw EvaluationError.invalidExpression("第 \(index + 1) 个字符附近存在无法解析的内容。")
      }
      return try finite(value)
    }

    private mutating func parseExpression(depth: Int) throws -> Double {
      try validate(depth: depth)
      return try parseAdditionAndSubtraction(depth: depth)
    }

    private mutating func parseAdditionAndSubtraction(depth: Int) throws -> Double {
      var value = try parseMultiplicationAndDivision(depth: depth)

      while true {
        if consume("+") {
          value = try finite(value + parseMultiplicationAndDivision(depth: depth))
        } else if consume("-") {
          value = try finite(value - parseMultiplicationAndDivision(depth: depth))
        } else {
          return value
        }
      }
    }

    private mutating func parseMultiplicationAndDivision(depth: Int) throws -> Double {
      var value = try parseUnary(depth: depth)

      while true {
        if consume("*") {
          value = try finite(value * parseUnary(depth: depth))
        } else if consume("/") {
          let divisor = try parseUnary(depth: depth)
          guard divisor != 0 else {
            throw EvaluationError.divisionByZero
          }
          value = try finite(value / divisor)
        } else {
          return value
        }
      }
    }

    // Unary signs bind less tightly than exponentiation on their right. Power's
    // right operand is unary, allowing both -2^2 == -4 and 2^-2 == 0.25.
    private mutating func parseUnary(depth: Int) throws -> Double {
      try validate(depth: depth)
      if consume("+") {
        return try parseUnary(depth: depth + 1)
      }
      if consume("-") {
        return try finite(-parseUnary(depth: depth + 1))
      }
      return try parsePower(depth: depth)
    }

    private mutating func parsePower(depth: Int) throws -> Double {
      let base = try parsePercentage(depth: depth)
      if consume("^") {
        let exponent = try parseUnary(depth: depth + 1)
        return try finite(Foundation.pow(base, exponent))
      }
      return base
    }

    private mutating func parsePercentage(depth: Int) throws -> Double {
      var value = try parsePrimary(depth: depth)
      while consume("%") {
        value = try finite(value / 100)
      }
      return value
    }

    private mutating func parsePrimary(depth: Int) throws -> Double {
      try validate(depth: depth)
      skipWhitespace()

      if consume("(") {
        let value = try parseExpression(depth: depth + 1)
        guard consume(")") else {
          throw isAtEnd
            ? EvaluationError.missingClosingParenthesis
            : EvaluationError.invalidExpression("括号内包含无法解析的内容。")
        }
        return value
      }

      if let number = try parseNumber() {
        return number
      }

      if let identifier = parseIdentifier() {
        let normalized = identifier.lowercased()
        if let constant = constant(named: normalized) {
          return constant
        }

        guard consume("(") else {
          throw EvaluationError.unknownIdentifier(identifier)
        }
        let argument = try parseExpression(depth: depth + 1)
        guard consume(")") else {
          throw isAtEnd
            ? EvaluationError.missingClosingParenthesis
            : EvaluationError.invalidExpression("函数参数后缺少右括号。")
        }
        return try apply(function: normalized, to: argument, originalName: identifier)
      }

      if isAtEnd {
        throw EvaluationError.incompleteExpression
      }
      throw EvaluationError.invalidExpression("第 \(index + 1) 个字符不是有效的数字、函数或常量。")
    }

    private mutating func parseNumber() throws -> Double? {
      skipWhitespace()
      let start = index
      var hasDigits = false

      while peek?.isASCIIDigit == true {
        hasDigits = true
        advance()
      }

      if consumeWithoutSkipping(".") {
        while peek?.isASCIIDigit == true {
          hasDigits = true
          advance()
        }
      }

      guard hasDigits else {
        index = start
        return nil
      }

      if peek == "e" || peek == "E" {
        advance()
        if peek == "+" || peek == "-" {
          advance()
        }
        let exponentStart = index
        while peek?.isASCIIDigit == true {
          advance()
        }
        guard index > exponentStart else {
          throw EvaluationError.invalidExpression("科学计数法的指数不完整。")
        }
      }

      guard let value = Double(String(characters[start..<index])) else {
        throw EvaluationError.invalidExpression("数字格式不正确。")
      }
      return try finite(value)
    }

    private mutating func parseIdentifier() -> String? {
      skipWhitespace()
      let start = index
      while peek?.isASCIILetter == true {
        advance()
      }
      guard index > start else { return nil }
      return String(characters[start..<index])
    }

    private func constant(named name: String) -> Double? {
      switch name {
      case "pi":
        return Double.pi
      case "e":
        return M_E
      default:
        return nil
      }
    }

    private func apply(function name: String, to value: Double, originalName: String) throws -> Double {
      let result: Double
      switch name {
      case "sqrt":
        result = Foundation.sqrt(value)
      case "abs":
        result = Swift.abs(value)
      case "round":
        result = value.rounded()
      case "floor":
        result = Foundation.floor(value)
      case "ceil":
        result = Foundation.ceil(value)
      case "sin":
        result = Foundation.sin(value)
      case "cos":
        result = Foundation.cos(value)
      case "tan":
        result = Foundation.tan(value)
      case "log":
        result = Foundation.log10(value)
      case "ln":
        result = Foundation.log(value)
      default:
        throw EvaluationError.unknownIdentifier(originalName)
      }
      return try finite(result)
    }

    private func finite(_ value: Double) throws -> Double {
      guard value.isFinite else {
        throw EvaluationError.nonFiniteResult
      }
      return value
    }

    private func validate(depth: Int) throws {
      guard depth <= Self.maximumDepth else {
        throw EvaluationError.expressionTooDeep
      }
    }

    private var peek: Character? {
      index < characters.count ? characters[index] : nil
    }

    private var isAtEnd: Bool {
      index >= characters.count
    }

    private mutating func advance() {
      index += 1
    }

    private mutating func skipWhitespace() {
      while peek?.isWhitespace == true {
        advance()
      }
    }

    private mutating func consume(_ expected: Character) -> Bool {
      skipWhitespace()
      return consumeWithoutSkipping(expected)
    }

    private mutating func consumeWithoutSkipping(_ expected: Character) -> Bool {
      guard peek == expected else { return false }
      advance()
      return true
    }
  }
}

private extension Character {
  var isASCIIDigit: Bool {
    self >= "0" && self <= "9"
  }

  var isASCIILetter: Bool {
    (self >= "a" && self <= "z") || (self >= "A" && self <= "Z")
  }
}
