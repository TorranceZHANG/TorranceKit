import AppKit
import SwiftUI

enum AppLaunchBehavior {
  static let backgroundLaunchArgument = "--background-launch"

  static func shouldShowPicker(arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
    !arguments.contains(backgroundLaunchArgument)
  }
}

@main
struct TorranceKitApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @StateObject private var model = AppModel.shared

  var body: some Scene {
    MenuBarExtra("TorranceKit", systemImage: "square.grid.2x2.fill") {
      TorranceKitMenuView(model: model)
    }
    .menuBarExtraStyle(.menu)
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    AppModel.shared.start()
    guard AppLaunchBehavior.shouldShowPicker() else { return }
    // Let the menu-bar scene finish launching before making the accessory panel key.
    // Showing it in the same run-loop turn can make macOS immediately resign and hide it.
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
      AppModel.shared.showPicker()
    }
  }

  func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    AppModel.shared.showPicker()
    return false
  }

  func applicationWillTerminate(_ notification: Notification) {
    AppModel.shared.stop()
  }
}

private struct TorranceKitMenuView: View {
  @ObservedObject var model: AppModel
  @ObservedObject private var history: ClipboardHistory
  @ObservedObject private var permission: AccessibilityPermission
  @ObservedObject private var configuration: AppConfiguration

  init(model: AppModel) {
    self.model = model
    history = model.history
    permission = model.permission
    configuration = model.configuration
  }

  var body: some View {
    Button("打开剪贴板（\(configuration.settings.hotKey.displayText)）") {
      model.showPicker()
    }

    Divider()

    Toggle("记录剪贴板", isOn: $model.isCaptureEnabled)

    if configuration.settings.autoPaste && !permission.isTrusted {
      Button("开启自动粘贴权限…") {
        permission.request()
      }
    }

    Button("清空 \(history.items.count) 条历史记录…") {
      model.confirmAndClearHistory()
    }
    .disabled(history.items.isEmpty)

    Divider()

    Button("设置…") {
      model.showSettings()
    }
    .keyboardShortcut(",", modifiers: .command)

    Divider()

    Text("TorranceKit · \(AppVersion.displayText)")

    Divider()

    Button("退出 TorranceKit") {
      NSApp.terminate(nil)
    }
    .keyboardShortcut("q")
  }
}
