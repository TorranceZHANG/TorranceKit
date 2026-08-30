import Foundation

enum AppVersion {
  static var shortVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "开发版"
  }

  static var buildNumber: String? {
    guard
      let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
      !value.isEmpty
    else {
      return nil
    }
    return value
  }

  static var displayText: String {
    if let buildNumber {
      return "版本 \(shortVersion)（\(buildNumber)）"
    }
    return "版本 \(shortVersion)"
  }
}
