import XCTest

@testable import TorranceKit

final class CalculatorEngineTests: XCTestCase {
  func testArithmeticPrecedenceAndParentheses() throws {
    XCTAssertEqual(try CalculatorEngine.evaluate("1 + 2 * 3"), "7")
    XCTAssertEqual(try CalculatorEngine.evaluate("(1 + 2) * 3"), "9")
    XCTAssertEqual(try CalculatorEngine.evaluate("7 / 2"), "3.5")
  }

  func testExponentiationIsRightAssociativeAndHasConventionalUnaryPrecedence() throws {
    XCTAssertEqual(try CalculatorEngine.evaluate("-2^2"), "-4")
    XCTAssertEqual(try CalculatorEngine.evaluate("2^-2"), "0.25")
    XCTAssertEqual(try CalculatorEngine.evaluate("2^3^2"), "512")
  }

  func testPercentageIsAPostfixOperator() throws {
    XCTAssertEqual(try CalculatorEngine.evaluate("200 * 10%"), "20")
    XCTAssertEqual(try CalculatorEngine.evaluate("-50%"), "-0.5")
  }

  func testDecimalsScientificNotationAndEqualsPrefix() throws {
    XCTAssertEqual(try CalculatorEngine.evaluate("= .5 + 5."), "5.5")
    XCTAssertEqual(try CalculatorEngine.evaluate("1.25e2 + 5E-1"), "125.5")
    XCTAssertEqual(try CalculatorEngine.evaluate("0.1 + 0.2"), "0.3")
  }

  func testFunctionsAndConstants() throws {
    XCTAssertEqual(try CalculatorEngine.evaluate("sqrt(81) + abs(-3)"), "12")
    XCTAssertEqual(try CalculatorEngine.evaluate("round(2.6) + floor(2.9) + ceil(2.1)"), "8")
    XCTAssertEqual(try CalculatorEngine.evaluate("sin(pi / 2)"), "1")
    XCTAssertEqual(try CalculatorEngine.evaluate("cos(0) + tan(0)"), "1")
    XCTAssertEqual(try CalculatorEngine.evaluate("log(1000)"), "3")
    XCTAssertEqual(try CalculatorEngine.evaluate("ln(e)"), "1")
  }

  func testErrorsHaveClearChineseDescriptions() {
    assertError("", contains: "请输入")
    assertError("1 +", contains: "不完整")
    assertError("(1 + 2", contains: "缺少右括号")
    assertError("1 / 0", contains: "除以零")
    assertError("unknown(1)", contains: "无法识别")
    assertError("sqrt(-1)", contains: "有限数值")
  }

  func testRejectsCodeLikeAndUnsupportedInput() {
    let maliciousInputs = [
      "Process()",
      "NSExpression(format: '1+1')",
      "1; system('whoami')",
      "`whoami`",
      "10 % 3",
    ]

    for expression in maliciousInputs {
      XCTAssertThrowsError(try CalculatorEngine.evaluate(expression), expression)
    }
  }

  func testRejectsExcessiveLengthAndNesting() {
    assertError(String(repeating: "1", count: 1_025), contains: "过长")

    let deeplyNested =
      String(repeating: "(", count: 65) + "1" + String(repeating: ")", count: 65)
    assertError(deeplyNested, contains: "嵌套过深")
  }

  func testRejectsOverflowAndIncompleteScientificNotation() {
    assertError("10^1000", contains: "有限数值")
    assertError("1e+", contains: "指数不完整")
  }

  private func assertError(
    _ expression: String,
    contains expectedText: String,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    XCTAssertThrowsError(
      try CalculatorEngine.evaluate(expression),
      file: file,
      line: line
    ) { error in
      XCTAssertTrue(
        error.localizedDescription.contains(expectedText),
        "错误信息“\(error.localizedDescription)”应包含“\(expectedText)”",
        file: file,
        line: line
      )
    }
  }
}
