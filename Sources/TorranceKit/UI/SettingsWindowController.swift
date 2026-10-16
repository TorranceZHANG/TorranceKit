import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
  private unowned let appModel: AppModel
  private let settingsViewModel: SettingsViewModel
  private var preservesDraftAfterAuthorization = false

  init(appModel: AppModel) {
    self.appModel = appModel
    settingsViewModel = SettingsViewModel(
      settings: appModel.configuration.settings,
      saveHandler: { [unowned appModel] settings in
        try appModel.saveConfiguration(settings)
      },
      reloadHandler: { [unowned appModel] in
        try appModel.reloadConfigurationFromDisk()
      },
      openJSONHandler: { [unowned appModel] in
        appModel.openConfiguration()
      },
      revealJSONHandler: { [unowned appModel] in
        appModel.revealConfiguration()
      }
    )

    let hostingController = NSHostingController(
      rootView: SettingsView(model: settingsViewModel, permission: appModel.permission)
    )
    let window = NSWindow(contentViewController: hostingController)
    window.title = "TorranceKit 设置 · \(AppVersion.shortVersion)"
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    window.minSize = NSSize(width: 660, height: 600)
    window.setContentSize(NSSize(width: 720, height: 680))
    window.isReleasedWhenClosed = false
    window.setFrameAutosaveName("TorranceKitSettingsWindow")
    window.center()

    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func show() {
    if window?.isVisible != true && !preservesDraftAfterAuthorization {
      settingsViewModel.load(appModel.configuration.settings)
    }
    preservesDraftAfterAuthorization = false
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
    window?.makeKeyAndOrderFront(nil)
  }

  func hideForAccessibilityRequest() {
    if window?.isVisible == true { preservesDraftAfterAuthorization = true }
    window?.orderOut(nil)
  }
}
