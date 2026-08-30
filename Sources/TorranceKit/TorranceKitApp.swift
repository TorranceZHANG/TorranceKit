import AppKit
import SwiftUI

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
    AppModel.shared.start()
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

    Toggle(
      "在程序坞显示图标",
      isOn: Binding(
        get: { configuration.settings.showDockIcon },
        set: { model.setDockIconVisible($0) }
      )
    )

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
